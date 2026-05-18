package arubaoscx;
##
## rancid 3.2.99
## Copyright (c) 1997-2022 by Henry Kilmer and John Heasley
## All rights reserved.
##
## This code is derived from software contributed to and maintained by
## Henry Kilmer, John Heasley, Andrew Partan,
## Pete Whiting, Austin Schutz, and Andrew Fort.
##
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions
## are met:
## 1. Redistributions of source code must retain the above copyright
##    notice, this list of conditions and the following disclaimer.
## 2. Redistributions in binary form must reproduce the above copyright
##    notice, this list of conditions and the following disclaimer in the
##    documentation and/or other materials provided with the distribution.
## 3. Neither the name of RANCID nor the names of its
##    contributors may be used to endorse or promote products derived from
##    this software without specific prior written permission.
##
## THIS SOFTWARE IS PROVIDED BY Henry Kilmer, John Heasley AND CONTRIBUTORS
## ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
## TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
## PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COMPANY OR CONTRIBUTORS
## BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
## CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
## SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
## INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
## CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
## ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
## POSSIBILITY OF SUCH DAMAGE.
##
## It is the request of the authors, but not a condition of license, that
## parties packaging or redistributing RANCID NOT distribute altered versions
## of the etc/rancid.types.base file nor alter how this file is processed nor
## when in relation to etc/rancid.types.conf.  The goal of this is to help
## suppress our support costs.  If it becomes a problem, this could become a
## condition of license.
# 
#  The expect login scripts were based on Erik Sherk's gwtn, by permission.
# 
#  The original looking glass software was written by Ed Kern, provided by
#  permission and modified beyond recognition.
#
#  RANCID - Really Awesome New Cisco confIg Differ
#
# arubaoscx.pm - Aruba OSCX switches
#
# Contributed by J R Binks <jrbinks+rancid@gmail.com>
#
# Tested on:
#
# * Aruba JL658A 6300M
# * Aruba JL635A 8325-48Y8C
# * Aruba JL636A 8325-32C
# * Aruba R8Q69A 6200M
# * v10.5 - v10.13
#
# A public version of this is occasionally updated at:
#
#   https://github.com/jrbinks/rancid-arubaoscx
#

use 5.010;
use strict 'vars';
use warnings;
no warnings 'uninitialized';
require(Exporter);
our @ISA = qw(Exporter);

use rancid 3.2.99;
#use rancid;

@ISA = qw(Exporter rancid main);

# load-time initialization
sub import {
    0;
}

# post-open(collection file) initialization
sub init {
    # add content lines and separators
    ProcessHistory("","","","!RANCID-CONTENT-TYPE: $devtype\n!\n");

    0;
}

# main loop of input of device output
sub inloop {
    my($INPUT, $OUTPUT) = @_;
    my($cmd, $rval);

TOP: while(<$INPUT>) {
        tr/\015//d;
        if (/[\]>#]\s*exit$/ || $found_end ) {
            $clean_run = 1;
            last;
        }
        if (/^Error:/) {
            print STDOUT ("$host $lscript error: $_");
            print STDERR ("$host $lscript error: $_") if ($debug);
            $clean_run = 0;
            last;
        }
        while (/[\]>#]\a?\s*($cmds_regexp)\s*$/) {
            $cmd = $1;
            if (!defined($prompt)) {
                $prompt = ($_ =~ /^([^#>]+[#>])/)[0];
                $prompt =~ s/([][}{)(+\\])/\\$1/g;
                print STDERR ("PROMPT MATCH: $prompt\n") if ($debug);
            }
            print STDERR ("HIT COMMAND:$_") if ($debug);
            if (! defined($commands{$cmd})) {
                print STDERR "$host: found unexpected command - \"$cmd\"\n";
                $clean_run = 0;
                last TOP;
            }
            if (! defined(&{$commands{$cmd}})) {
                printf(STDERR "$host: undefined function - \"%s\"\n",
                       $commands{$cmd});
                $clean_run = 0;
                last TOP;
            }
            $rval = &{$commands{$cmd}}($INPUT, $OUTPUT, $cmd);
            delete($commands{$cmd});
            if ($rval == -1) {
                $clean_run = 0;
                last TOP;
            }
        }
    }
}


# dummy function
sub DoNothing {print STDOUT;}

# Clean up lines on input
sub filter_lines {
    my ($l) = (@_);
    # spaces at end of line:
    $l =~ s/\s+$//g;
    return $l;
}

# Some commands are not supported on some models or versions
# of code.
# Remove the associated error messages, and rancid will ensure that
# these are not treated as "missed" commands

# On ArubaOSCX, it seems a command for which you are not authorised is
# just not visible and treated as invalid
sub command_not_valid {
    my ($l) = (@_);

    if ( $l =~
        /Invalid input: / ||
        /% Command incomplete./
    ) {
        return(1);
    } else {
        return(0);
    }
}

# Some commands are not authorized under the current
# user's permissions
sub command_not_auth {
    my ($l) = (@_);

    if ( $l =~
        # nothing needed here so far so just use a placeholder
        /XXXXPLACEHOLDERXXX/
    ) {
        return(1);
    } else {
        return(0);
    }
}

# Some output lines are always skipped
sub skip_pattern {
    my ($l) = (@_);

    if ( $l =~
        /^\s+\^$/
    ) {
        return(1);
    } else {
        return(0);
    }
}

sub IPPimNbrBr {
    my($INPUT, $OUTPUT, $cmd) = @_;
    my $sub_name = (caller(0))[3];
    print STDERR "    In $sub_name: $_" if ($debug);

    my $fmt = "%-12.12s %-16.16s %-11.11s %-16.48s";
    my $seen_header = 0;
    my @data_lines;
    my $in_data = 0;

    ProcessHistory("IPPIMNBR", "", "", "!\n! '$cmd':\n!\n");

    while (<$INPUT>) {
        tr/\015//d;

        last if (/^$prompt/);
        chomp;
        $_ = filter_lines($_);
        return(1) if command_not_valid($_);
        return(-1) if command_not_auth($_);
        next if skip_pattern($_);
        next if /^$/;

        # It's too fiddly to try and mangle the header, so we just create a new
        # one to fit the data into

        next if ( /^-------------------------------/ );

        if ( /(\s+)(VRF ?: \S+)\s+(Total number of neighbors ?: \d+)/ ) {
            ProcessHistory("IPPIMNBR", "", "", "! $2    $3\n\n");
            next;
        }

        if ( /^(Interface|\s+\(IPV4|----------- )/ ) {
            next if $seen_header;
            # This spacing is designed to match $fmt
            my $hdr1 = "Interface    Neighbor         DR          Secondary Address";
            my $hdr2 = "             (IPV4)           Priority    (IPV4)";
            my $hdr3 = "------------ ---------------- ----------- -----------------";
            ProcessHistory("IPPIMNBR", "", "", "! $hdr1\n");
            ProcessHistory("IPPIMNBR", "", "", "! $hdr2\n");
            ProcessHistory("IPPIMNBR", "", "", "! $hdr3\n");
            $seen_header = 1;
            next;
        }

        # Collect the data lines
        if ( /^(\S+) {2,}([\d\.]+)\s+(.+) {2,}([\d:]+)\s+(\d+)\s+([\d:]+)\s+(.+)$/ ) {
            my ($int, $nbr, $prio, $sec) = ($1, $2, $5, $7);
            $sec =~ s/( +)?, +/, /;
            push(@data_lines, sprintf($fmt, $int, $nbr, $prio, $sec));
            $in_data = 1;
            next;
        }

        # If a line starts with a space, then this may be a continuation of the
        # previous data line, so we need to append it
        if ( /^\s+(.+)$/ && $in_data ) {
            my $val = pop(@data_lines);
            push(@data_lines, "$val, $1");
            next;
        }

        # Output any other lines
        ProcessHistory("IPPIMNBR", "", "", "! $_\n");

    }

    # Sort and output the data lines
    foreach my $data_line ( sort @data_lines ) {
        ProcessHistory("IPPIMNBR", "", "", "! $data_line\n");
    }

    ProcessHistory("IPPIMNBR", "", "", "!\n");
    return(0);

}


sub IPPimRPSet {
    my($INPUT, $OUTPUT, $cmd) = @_;
    my $sub_name = (caller(0))[3];
    print STDERR "    In $sub_name: $_" if ($debug);

    # The output has some volatile fields that need removing, and
    # the order of the rp-set lines varies between runs so we need
    # to do some sorting

    my $fmt = "%-16.16s %-16.16s %-16.16s %-8.8s";
    my $underline = "-" x 30;
    my @data_lines;

    ProcessHistory("IPPIMRPSET", "", "", "!\n! '$cmd':\n!\n");

    while (<$INPUT>) {
        tr/\015//d;

        last if (/^$prompt/);
        chomp;
        $_ = filter_lines($_);
        return(1) if command_not_valid($_);
        return(-1) if command_not_auth($_);
        next if skip_pattern($_);
        next if /^$/;

        # Match the header line and replace
        if ( /^(Group Address)(\s+Group Mask)(\s+RP Address)(\s+Hold Time)(\s+Expire Time)(\s+Priority)?/ ) {
            my $hdr = sprintf($fmt, "Group Address", "Group Mask", "RP Address", "Priority");
            ProcessHistory("IPPIMRPSET", "", "", "! $hdr\n");
            next;
        }

        # Match the underlines and replace
        if ( /^---/ ) {
            my $uline = sprintf($fmt, $underline, $underline, $underline, $underline);
            ProcessHistory("IPPIMRPSET", "", "", "! $uline\n");
            next;
        }

        # Collect the data lines
        if ( /^([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+(\d+)\s+(\d+)(\s+)?(\d+)?/ ) {
            push(@data_lines, sprintf($fmt, $1, $2, $3, $7 || "-"));
            next;
        }

        # Output any other lines
        ProcessHistory("IPPIMRPSET", "", "", "! $_\n");

    }

    # Sort and output the data lines
    foreach my $data_line ( sort @data_lines ) {
        ProcessHistory("IPPIMRPSET", "", "", "! $data_line\n");
    }

    ProcessHistory("IPPIMRPSET", "", "", "!\n");
    return(0);
 
}


## This routine processes general output of "display" commands
sub CommentOutput {
    my($INPUT, $OUTPUT, $cmd) = @_;
    my $sub_name = (caller(0))[3];
    print STDERR "    In $sub_name: $_" if ($debug);

    my $in_fan_info = 0;
    my $reached_bgpv4_nbrs = 0;
    my $reached_bgpv6_nbrs = 0;
    my $ospf_stat_underline = "";

    chomp;

    # Display the command we're processing in the output:
    # Some commands may result in no output if $filter_osc is set
    # and so this is a kludgy way to not have the commands itself show
    # up either, if that's what you want.  Personally, I don't mind
    # the command being shown even when it has no output.
    unless (
        (
            $cmd eq 'XXXXPLACEHOLDERXXXX' ||
            $cmd eq 'XXXXPLACEHOLDER2XXXX'
        ) && ( $filter_osc >= 1 )
    ) {
        ProcessHistory("COMMENTS", "", "", "!\n! '$cmd':\n!\n");
    }

    while (<$INPUT>) {
        tr/\015//d;

        # If we find the prompt, we're done
        last if (/^$prompt/);
        chomp;

        # filter out some junk
        $_ = filter_lines($_);
        return(1) if command_not_valid($_);
        return(-1) if command_not_auth($_);
        next if skip_pattern($_);

        # Now we skip or modify some lines from various commands to
        # remove irrelevant content, or to avoid insignificant diffs
        # More complex processing will have its own sub

        # 'show system':
        if ( $cmd eq 'show system' ) {
            next if /^Up Time\s+: /;
            next if /^CPU Util \(%\)\s+: /;
            next if /^CPU Util \(% avg \d+ min\)\s+: /;
            next if /^Memory Usage \(%\)\s+: /;
        }

        # 'show environment temperature'
        if ( $cmd eq 'show environment temperature' ) {
            next if /^\s+Current$/;
            my $fmt = "%-33s%-22s%-15s";
            if ( /^(Mbr\/Slot-Sensor)\s+(Module Type)\s+(temperature)\s+(Status)$/ ) {
                $_ = sprintf($fmt, $1, $2, $4);
            } elsif ( /^(\S+)\s+(\S+)\s+\d+\.\d+ C\s+(\S+)$/ ) {
                $_ = sprintf($fmt, $1, $2, $3);
            }
        }

        if ( $cmd eq 'show environment fan' ) {
            $in_fan_info = 1 if /Fan information/;
            s/(.+Status)\s+RPM/$1/;
            s/\s+\d+\s*$// if $in_fan_info;
        }

        if ( $cmd eq 'show vsf detail' ) {
            next if /\s+Uptime\s+:/;
            next if /\s+CPU Utilization\s+/;
            next if /\s+Memory Utilization\s+:/;
        }

        if ( $cmd eq 'show ip ospf' ) {
            # Old output format (at least to 10.5):
            next if /^Number of external LSAs/;
            next if /^\s+SPF calculation has run/;
            next if /^\s+Number of LSAs:/;
            # New output format (maybe from 10.09):
            next if /^External LSAs/;
            next if /^SPF Calculation Count/;
            next if /^Number of LSAs/;
        }

        if ( $cmd eq 'show ip ospf statistics' ) {
            if ( /, Statistics/ ) {
                s/, Statistics \(cleared .+ ago\)//g;
                $ospf_stat_underline = "-" x length($_);
            }
            # The following line is made up of ----- of length depending
            # on previous line, so is variable.
            # Replace with a more fixed length line.
            s/^-+$/$ospf_stat_underline/g if /---/;
        }

        if ( $cmd eq 'show ip pim bsr' ) {
            next if /^E-BSR Up Time/;
            next if /^Next Bootstrap Message/;
        }

        if ( $cmd eq 'show ntp status' ) {
            next if /^System time\s+:/;
            next if /^NTP uptime\s+:/;
            # If we are synchronised, we have this line.  Ignore the rest
            if (/NTP Synchronization Information/) {
                ProcessHistory("COMMENTS","","","! Synchronized with an NTP server.\n");
                last;
            }
            # If we aren't it says: "Not synchronized with an NTP server." which is fine
        }

        if ( $cmd eq 'show ip interface brief' ) {
            next if /^$/;
        }

        if ( $cmd eq 'show lldp neighbor-info' ) {
            next if /^Total Neighbor Entries (Deleted|Dropped|Aged-Out)\s+:/;
            # Some environments might not want to see output changes when LLDP
            # neighbours change; while one technique might be to set $filter_osc
            # and test for it here with:
            #
            #  next if ($filter_osc >= 1);
            #
            # I think that's an overreach for what the variable is supposed to
            # control.  See remarks at:
            # https://github.com/jrbinks/rancid-arubaoscx/pull/3
            #
            # If "show lldp neighbour-info" does cause lots undesirable output
            # changes in your environment, then consider commenting the command
            # out of rancid.type.conf.
        }

        if ( $cmd eq 'show ip ospf neighbors' ) {
            next if /^$/;
        }

        if ( $cmd eq 'show bgp ipv4 unicast summary' ) {
            $reached_bgpv4_nbrs = 1 if (/^\s+Neighbor/);
            s/(\s+)(Neighbor\s+)(\S+\s+)(\S+\s+)(\S+\s+)(\S+\s+)(\S+\s+)(\S+\s+)(\S+)(\s*)/$1$2$3  $8 $9/ if $reached_bgpv4_nbrs;
            s/(\S+\s+)(\S+\s+)(\S+\s+)(\S+\s+)(\S+\s+)(\S+\s+)(\S+)(\s*)/$1$2$6$7/ if $reached_bgpv4_nbrs;
        }

        if ( $cmd eq 'show bgp ipv6 unicast summary' ) {
            # We don't have any these, so this is a blind copy of the above
            $reached_bgpv6_nbrs = 1 if (/^ Neighbor/);
            s/(\s+)(Neighbor\s+)(\S+\s+)(\S+\s+)(\S+\s+)(\S+\s+)(\S+\s+)(\S+\s+)(\S+)(\s*)/$1$2$3  $8 $9/ if $reached_bgpv6_nbrs;
            s/(\S+\s+)(\S+\s+)(\S+\s+)(\S+\s+)(\S+\s+)(\S+\s+)(\S+)(\s*)/$1$2$6$7/ if $reached_bgpv6_nbrs;
        }

        # Add the processed lines to the output buffer:
        ProcessHistory("COMMENTS","","","! $_\n");
    }

    # Add a blank comment line to the output buffer
    ProcessHistory("COMMENTS", "", "", "!\n");
    return(0);

}


sub ShowConfiguration {
    my($INPUT, $OUTPUT, $cmd) = @_;
    my $sub_name = (caller(0))[3];
    print STDERR "    In $sub_name: $_" if ($debug);

    my($linecnt) = 0;

    while (<$INPUT>) {
        tr/\015//d;
        last if(/^\s*$prompt/);
        chomp;

        $_ = filter_lines($_);
        return(1) if command_not_valid($_);
        return(-1) if command_not_auth($_);
        next if skip_pattern($_);

        return(0) if ($found_end);

        $linecnt++;

        # Filter out sensitive data:

        # Secrets that are (may be) reversible
        if ($filter_pwds >= 1) {
            /^((user .+ password|tacacs-server .+) ciphertext )(\S+)/ &&
                ProcessHistory("","","","! $1<removed>$'\n") && next;
            /^(\s+ip ospf message-digest-key \d+ \S+ ciphertext )(\S+)/ &&
                ProcessHistory("","","","! $1<removed>$'\n") && next;
        }

        # Additionally, any secrets of any sort (even non-reversible ones)
        if ($filter_pwds >= 2) {
            # identify some 
        }

        # Oscillating data (possibly encoded secrets) in the config
        if ($filter_osc >= 1) {
            # identify some 
        }

        # SNMP Community strings
        if ($filter_commstr) {
            /^(snmp-server community )(\S+)/ &&
                ProcessHistory("","","","! $1<removed>$'\n") && next;
        }

        # Add anything not already handled
        ProcessHistory("", "", "", "$_\n");

    }

    # lacks a definitive "end of config" marker.
    if ($linecnt > 5) {
        $found_end = 1;
        return(0)
    }

    return(0);

}

1;
