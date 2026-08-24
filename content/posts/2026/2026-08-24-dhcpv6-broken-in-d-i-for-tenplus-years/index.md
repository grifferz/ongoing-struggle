+++
title = "DHCPv6 has been broken in the Debian Installer for 10+ years"
# No date needed because filename or containing directory should be of the
# form YYYY-MM-DD-slug and Zola can work it out from that.
description = """
As far as I can see, installs that require DHCPv6 have not been possible using
the Debian Installer for more than 10 years. A bug has been reported but I
suspect hasn't seen much attention because most people who have IPv6 use SLAAC.
"""

[taxonomies]
# see `docs/tags_in_use.md` for a list of all tags currently in use.
tags = [
    "debian",
    "ipv6",
]

[extra]
toc_levels = 2
+++

I've been working on a new way to provision the operating system (Debian) on
[BitFolk]'s hypervisor servers. As the internal networks are IPv6-only this
required some way to acquire initial connectivity. DHCPv6 seemed the obvious
choice, but it has not been at all plain sailing.

[BitFolk]: https://bitfolk.com/

{{ toc() }}

## TL;DR:

It seems that in 2015 the `netcfg` component of the [Debian Installer] was
modified to send a `SIGTERM` signal to all DHCP clients. The reasoning behind
this is covered in [bug #768188]. Unfortunately the DHCPv6 client in use has a
`SIGTERM` handler that issues a DHCP Release and removes the address from the
interface, meaning that IPv6 connectivity is lost and never regained. This was
reported in [bug #1072526] in 2024, which is still open today but does contain
some manual workarounds. Without using one of those workarounds it is not
possible to install Debian on an On an IPv6-only network that is managed by
DHCP, not SLAAC.

[Debian Installer]: https://www.debian.org/devel/debian-installer/
[bug #768188]: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=768188#100
[bug #1072526]: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1072526

## Environment

The hypervisor servers peer with our colo provider by BGP and inject /32
routes for individual IPv4 addresses and /48 routes for IPv6 blocks, along
with some /128s for individual IPv6 addresses. But before they ever have a BGP
daemon up and running on them they need some connectivity —
including/especially during install.

### Unique Local Addreses

As the servers all have 2x 1GbE and 2x 25GbE Ethernet, the 1GbE aren't used in
production. We decided to use these for a sort of internal provisioning
network using IPv6-only and [Unique Local Addresses] (ULAs). So, each server
is to have a unique address within `fdbf::/16` which will provide it
connectivity to only the rest of our infrastructure. To get outside our
network it would have to use proxies.

[Unique Local Addresses]: https://en.wikipedia.org/wiki/Unique_local_address

### /127 networks

To avoid any complications of [Neighbor Discovery exhaustion] attacks we use a
/127 network per server — only two on-net addresses; the server and its
gateway.

### No SLAAC

That also prevents us using [stateless address autoconfiguration] (SLAAC),
because that only works with /64 subnets. SLAAC is the thing where the router
advertises what network prefix is in use so that clients can configure
themselves an address.

### No RA

Since there's no SLAAC we won't need any [Router Advertisements] either,
though we do have the router respond to Router Solicitations as otherwise
there's no way for IPv6 hosts to wrk out what their gateway should be — no
"gateway" option in DHCPv6.

[Neighbor Discovery exhaustion]:
  https://blog.ipspace.net/2011/05/ipv6-neighbor-discovery-exhaustion/
[stateless address autoconfiguration]:
  https://en.wikipedia.org/wiki/IPv6_address#Stateless_address_autoconfiguration_(SLAAC)
[Router Advertisements]:
  https://docs.netgate.com/pfsense/en/latest/services/dhcp/ipv6-ra.html

### Thus, DHCPv6

Without SLAAC the only way to have a client automatically get an address is
going to be DHCPv6 so that's where we went. DHCPv6 was also a new thing for me
so this provided a Fun Learning Opportunity.

## Running the Debian Installer

### Boot

At the moment we have the [BMC] of the server mount the Debian Installer ISO
image over CIFS as a virtual DVD drive. The server's firmware is able to boot
from that and it also just appears as a regular USB-SCSI drive inside Linux.
We automate a fair bit of the install process with [preseeding] but that's not
important here. We're also probably going to switch to booting the installer
by [PXE], but again, not important.

[BMC]:
  https://en.wikipedia.org/wiki/Intelligent_Platform_Management_Interface#Baseboard_management_controller
[preseeding]: https://www.debian.org/releases/stable/amd64/apb.en.html
[PXE]: https://en.wikipedia.org/wiki/PXE_boot

### Network configuration

By default the installer offers to configure the network automatically. If
this is selected (manually or by preseed) then it first does an IPv6 Router
Solicitation, which gets it a default gateway of `fe80::1`. It then requests a
DHCPv6 lease which again goes well.

Next it asks for host name and domain name. Once these are supplied, network
connectivity mysteriously goes away.

What's happening is that `netcfg` is calling `/usr/bin/kill-all-dhcp` which
sends a `SIGTERM` signal to every process named `dhclient`, `udhcpc`, `pump`,
or `dhcp6c`. Unfortunately `dhcp6c` has a handler for `SIGTERM` that causes it
to issue a DHCP Release back to the DHCP server to release resources and then
it removes the IP address from the interface before exiting.

`dhcp6c` is never launched again so without SLAAC it's not possible to
complete a Debian install on an IPv6-only network.

This was reported in 224 in [bug #1072526], which is still open but does
contain some manual workarounds.

### Workarounds

The suggested patch to `kill-all-dhcp` merely issues a `SIGKILL` instead of a
`SIGTERM`. As `SIGKILL` cannot be caught this doesn't invoke `dgcp6c`'s
handler and the IP address stays configured. As far as I can see, if you want
a Debian Installer that you can automated in this environment then you'll need
to patch d-i and build your own ISO image.

If manual intervention is okay then at the point where the connectivity dies
you can switch to the installer's shell and issue:

```text
# dhcp6c -c /var/lib/netcfg/dhcpc6.conf eno1
## or whatever your network interface is
```

to launch a new `dhcp6c`.

I had wondered if the patch could be applied in a `preseed/early_command` to
avoid the hassle of having to build a new d-i image. Sadly the `early_command`
runs just before disk partitioning which is several questions after the
connectivity is removed.

Does anyone know of a way to run a command inside the installer really early
on, just after the `netcfg` udeb is installed?

Possibly what I can do is automate the preseed even more, and launch a new
`dhcp6c` in the `early_command`. Connectivity would still be lost between the
end of the "domain name" question and the start of the disk partitioner, but
if no questions need to be answered then that doesn't matter. If questions
_did_ need to be answered then I would have to manually run `dhcp6c` as above.

This whole idea of killing the SHCP clients is pretty gross though. I'm amazed
this has worked for so long for IPv4. Even though the DHCPv4 clients clearly
don't have a signal handler like `dhcp6c` does, this does leave the installer
environment in a state where it has no running DHCP client so nothing is
renewing the lease. You had better complete your install before your DHCP
server requires you to renew the lease!

I'm also a little surprised that it took until 2024 for someone to report this
bug. It looks like use of DHCPv6 is still really rare. If SLAAC or IPv4 are
present then the installer will use those and the problem wouldn't be noticed.
