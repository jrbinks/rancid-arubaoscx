# rancid-arubaoscx

# What This Is

A module for rancid (https://www.shrubbery.net/rancid/) to add support to rancid for Aruba's OS-CX models.

# What This Is Not

This module will not provide support for the following:

- Aruba wireless controllers/mobility switches running ArubaOS/AOS - try https://github.com/miken32/rancid-aruba
- Modern Aruba switches such as 2930F running ArubaOS-Switch/AOS-S - this is the new branding for ProvisionOS, and *should* be supported natively in rancid via device type 'hp' (running hlogin/hrancid) but changes may be required [to be tested]
- Aruba/HPE Comware devices (a rancid module I've written called cmw will help here, but I need to properly publish it.  You may find old versions floating around, good luck with those ...)


## Installation Requirements

rancid 3.x

## Installation Instructions

Copy `arubaoscx.pm` into your rancid lib directory (ie, `/usr/local/rancid/lib/rancid` or similar).

Add lines to your `rancid.types.conf`:

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
arubaoscx;command;arubaoscx::CommentOutput;show vsx brief
arubaoscx;command;arubaoscx::CommentOutput;show vsx status
arubaoscx;command;arubaoscx::CommentOutput;show vsx config-consistency
arubaoscx;command;arubaoscx::CommentOutput;show vsx lacp configuration
arubaoscx;command;arubaoscx::CommentOutput;show vsf
arubaoscx;command;arubaoscx::CommentOutput;show vsf detail
arubaoscx;command;arubaoscx::CommentOutput;show vsf link
arubaoscx;command;arubaoscx::CommentOutput;show vlan
arubaoscx;command;arubaoscx::CommentOutput;show ntp status
arubaoscx;command;arubaoscx::CommentOutput;show lldp neighbor-info
arubaoscx;command;arubaoscx::CommentOutput;show ip ospf
arubaoscx;command;arubaoscx::CommentOutput;show ip ospf interface
arubaoscx;command;arubaoscx::CommentOutput;show ip ospf neighbors
arubaoscx;command;arubaoscx::CommentOutput;show ip ospf statistics
arubaoscx;command;arubaoscx::CommentOutput;show bgp ipv4 unicast summary
arubaoscx;command;arubaoscx::CommentOutput;show bgp ipv6 unicast summary
arubaoscx;command;arubaoscx::ShowConfiguration;show running-config
```

Add devices to your `router.db`:

```
10.0.0.1;arubaoscx;up
```


## Compatibility

Tested with models:

- Aruba 6300M
- Aruba 8325

It will also likely work for 6200, 6100 and other models running ArubaOS-CX.

Tested with OSCX versions:

- 10.5
- 10.7

## Official Status

Not official.  I would like it to be included in the main rancid distribution ...
