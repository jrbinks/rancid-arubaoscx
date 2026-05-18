# rancid-arubaoscx

# What This Is

A module for rancid (https://www.shrubbery.net/rancid/) to add support to rancid for HPE Aruba Networking devices running ArubaOS-CX (AOS-CX).

# What This Is Not

This module will *not* provide support for the following:

- Aruba wireless controllers/mobility switches running ArubaOS/AOS - try https://github.com/miken32/rancid-aruba
- Modern Aruba switches (e.g, 2930F) running ArubaOS-Switch/AOS-S - this is the new branding for ProvisionOS, and *should* be supported natively in rancid via device type 'hp' (running hlogin/hrancid) but changes may be required [to be tested]
- HPE Comware devices (a rancid module I've written called cmw will help here, but I need to properly publish it.  You may find old versions floating around, good luck with those ...)


## Installation Requirements

rancid 3.x

## Installation Instructions

Copy `arubaoscx.pm` into your rancid lib directory (ie, `/usr/local/rancid/lib/rancid` or similar).

Note that it works fine with the standard `clogin`, and doesn't require its own login script.

Add lines to `rancid.types.conf`:

```
arubaoscx;script;rancid -t arubaoscx
arubaoscx;login;clogin
arubaoscx;module;arubaoscx
arubaoscx;inloop;arubaoscx::inloop
arubaoscx;command;rancid::RunCommand;no page
# system commands
arubaoscx;command;arubaoscx::CommentOutput;show system
arubaoscx;command;arubaoscx::CommentOutput;show version
arubaoscx;command;arubaoscx::CommentOutput;show images
# hardware commands
arubaoscx;command;arubaoscx::CommentOutput;show module
arubaoscx;command;arubaoscx::CommentOutput;show environment power-supply
arubaoscx;command;arubaoscx::CommentOutput;show environment power-redundancy
arubaoscx;command;arubaoscx::CommentOutput;show environment fan
arubaoscx;command;arubaoscx::CommentOutput;show environment temperature
arubaoscx;command;arubaoscx::CommentOutput;show environment led
arubaoscx;command;arubaoscx::CommentOutput;show interface transceiver
# system state commands
#arubaoscx;command;arubaoscx::CommentOutput;show ntp status
arubaoscx;command;arubaoscx::CommentOutput;show ntp servers
arubaoscx;command;arubaoscx::CommentOutput;show ntp authentication-keys
arubaoscx;command;arubaoscx::CommentOutput;show front-panel-security status
arubaoscx;command;arubaoscx::CommentOutput;show usb
arubaoscx;command;arubaoscx::CommentOutput;show bluetooth
arubaoscx;command;arubaoscx::CommentOutput;show secure-mode
arubaoscx;command;arubaoscx::CommentOutput;show password-complexity
arubaoscx;command;arubaoscx::CommentOutput;show service export-password
arubaoscx;command;arubaoscx::CommentOutput;show aaa accounting
arubaoscx;command;arubaoscx::CommentOutput;show aaa authentication
arubaoscx;command;arubaoscx::CommentOutput;show aaa authorization
arubaoscx;command;arubaoscx::CommentOutput;show aaa server-groups
arubaoscx;command;arubaoscx::CommentOutput;show user-list
arubaoscx;command;arubaoscx::CommentOutput;show user-list management-interface
arubaoscx;command;arubaoscx::CommentOutput;show ssh server vrf mgmt
arubaoscx;command;arubaoscx::CommentOutput;show ssh server vrf default
arubaoscx;command;arubaoscx::CommentOutput;show ssh server allow-list
arubaoscx;command;arubaoscx::CommentOutput;show snmp system
arubaoscx;command;arubaoscx::CommentOutput;show snmp community
arubaoscx;command;arubaoscx::CommentOutput;show crypto pki certificate
arubaoscx;command;arubaoscx::CommentOutput;show tls
arubaoscx;command;arubaoscx::CommentOutput;show vsx brief
arubaoscx;command;arubaoscx::CommentOutput;show vsx status
arubaoscx;command;arubaoscx::CommentOutput;show vsx config-consistency
arubaoscx;command;arubaoscx::CommentOutput;show vsx lacp configuration
arubaoscx;command;arubaoscx::CommentOutput;show vsf
arubaoscx;command;arubaoscx::CommentOutput;show vsf detail
arubaoscx;command;arubaoscx::CommentOutput;show vsf link
arubaoscx;command;arubaoscx::CommentOutput;show interface mgmt
arubaoscx;command;arubaoscx::CommentOutput;show interface brief
arubaoscx;command;arubaoscx::CommentOutput;show ip interface brief
arubaoscx;command;arubaoscx::CommentOutput;show vlan
arubaoscx;command;arubaoscx::CommentOutput;show lldp neighbor-info
arubaoscx;command;arubaoscx::CommentOutput;show ip ospf
arubaoscx;command;arubaoscx::CommentOutput;show ip ospf interface
arubaoscx;command;arubaoscx::CommentOutput;show ip ospf neighbors
arubaoscx;command;arubaoscx::CommentOutput;show ip ospf statistics
arubaoscx;command;arubaoscx::CommentOutput;show bgp ipv4 unicast summary
arubaoscx;command;arubaoscx::CommentOutput;show bgp ipv6 unicast summary
arubaoscx;command;arubaoscx::CommentOutput;show ip pim
arubaoscx;command;arubaoscx::IPPimRPSet;show ip pim rp-set
arubaoscx;command;arubaoscx::IPPimNbrBr;show ip pim neighbor brief
arubaoscx;command;arubaoscx::CommentOutput;show ip pim bsr
arubaoscx;command;arubaoscx::ShowConfiguration;show running-config
```

Add devices to your `router.db`:

```
10.0.0.1;arubaoscx;up
```

Add clauses to your `.cloginrc`, something like:

```
add password 10.0.0.1 {PLACEHOLDER-NOTUSED}
add identity 10.0.0.1 {~/ssh/id_rancid}
add user 10.0.0.1 rancid
add method 10.0.0.1 ssh
add noenable 10.0.0.1 1
add cyphertype 10.0.0.1 {aes128-ctr}
```

The user you specify will probably need to be in the administrators group on the switch:

```
conf t
user rancid group administrators
exit
```

## Compatibility

Tested with models from:

- Aruba 6300 series (e.g. JL658A 6300M)
- Aruba 8300 series (e.g. JL635A 8325-48Y8C)
- Aruba 6100 series (e.g. JL675A 6100)
- Aruba 6200 series (e.g. R8Q69A 6200M)

It will also likely work for 6200, 6100 and other models running ArubaOS-CX.

Tested with ArubaOS-CX versions:

- 10.5 - 10.13

I have also heard it works fine with 10.16, but not tested myself.

## Official Status

Not official.  I would like it to be included in the main rancid distribution ...

## Hints

Some output captured by this module reflects the state of the network
and connected devices, rather than the device itself  If your environment is
quite volatile, you may not care to be seeing these changes.  If so, then
consider commenting out relevant lines from `rancid.types.conf`.  For
example, you might consider the following:

```
#arubaoscx;command;arubaoscx::CommentOutput;show lldp neighbor-info
#arubaoscx;command;arubaoscx::CommentOutput;show ip ospf neighbors
#arubaoscx;command;arubaoscx::IPPimNbrBr;show ip pim neighbor brief
```

