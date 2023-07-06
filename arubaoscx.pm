package arubaoscx;
##
## rancid 3.2.99
#
#  RANCID - Really Awesome New Cisco confIg Differ
#
# arubaoscx.pm - Aruba OSCX switches
#
# Contributed by J R Binks <jrbinks+rancid@gmail.com>
#
# Tested on:
#
# Aruba JL658A 6300M 
# Aruba JL635A 8325-48Y8C
# v10.5

use 5.010;
use strict 'vars';
use warnings;
no warnings 'uninitialized';
require(Exporter);
our @ISA = qw(Exporter);

#use rancid 3.13;
#use rancid 3.2.99;
use rancid 3.2.99;
use rancid;

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
    ProcessHistory("COMMENTS", "", "", "!\n! '$cmd':\n!\n");

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
            next if /\s+Current\s+/;
            s/(.+Module Type\s+)temperature\s(Status.+)/$1$2/;
            s/(\s+)\d+\.\d+ C(.+)/$1$2/;
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

        if ( $cmd eq 'show lldp neighbor-info' ) {
            next if /^Total Neighbor Entries (Deleted|Dropped|Aged-Out)\s+:/;
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

        # Filter out some sensitive data:
        if ( $filter_commstr &&
             /^(snmp-server community )(\S+)/
           ) {
            ProcessHistory("","","","! $1<removed>$'\n");
            next;
        }
        if ( $filter_pwds >= 1 &&
            /^((user .+ password|tacacs-server .+) ciphertext )(\S+)/

           ) {
            ProcessHistory("","","","! $1<removed>$'\n");
            next;
        }

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

__END__


