+++
title = "Linux, IPv6, router advertisements and forwarding"
description = """
How to enable IPv6 routing on Linux wile still learning your default route
from SLAAC
"""

[taxonomies]
tags = [
    "debian",
    "ipv6",
    "linux",
    "migrated-from-wordpress",
]

[extra]
# On the basis that this was already published and doesn't need to be fed out
# again…
hide_from_feed = true
+++

By default, a Linux host on an IPv6 network will listen for and solicit router
advertisements in order to choose an IPv6 address for itself and to set up its
default route. This is referred to as
[stateless address autoconfiguration (SLAAC)](http://en.wikipedia.org/wiki/IPv6_address#Stateless_address_autoconfiguration).

If you don't want a host to automatically configure an address and route then
you could disable this behaviour by writing `0` to
`/proc/sys/net/ipv6/conf/*/accept_ra`.

```txt
# for f in /proc/sys/net/ipv6/conf/*/accept_ra; do \
echo "0" > "$f"; \
done
```

Additionally, _if the Linux host considers itself to be a router then it will
ignore all router advertisements_.

In this context, what makes the difference between router or not are the
settings of the `/proc/sys/net/ipv6/conf/\*/forwarding` files (or the
`net.ipv6.conf.\*.forwarding` sysctl). If you turn your host into a router by
setting one of those to `1`, you may find that your host removes any IPv6
address and default route it learned via SLAAC.

There is a valid argument that a router should not be autoconfiguring itself,
and should have its addresses and routes configured statically. Linux has IP
forwarding features for a reason though, and sometimes you want to forward
packets with a Linux box while still enjoying autoconfiguration. In my case I
have some hosts running virtual machines, with IPv6 prefixes routed to the
virtual machines. I'd still like the hosts to learn their default route via
SLAAC.

It's taken me a long time to work out how to do this. It isn't
well-documented.

Firstly, if you have a kernel version of 2.6.37 or higher then your answer is
to set `accept_ra` to `2`. From
[ip-sysctl.txt](http://www.kernel.org/doc/Documentation/networking/ip-sysctl.txt):

> accept_ra - BOOLEAN
>
> > Accept Router Advertisements; autoconfigure using them.
> >
> > Possible values are:
> >
> > - 0 Do not accept Router Advertisements.
> > - 1 Accept Router Advertisements if forwarding is disabled.
> > - 2 Overrule forwarding behaviour. Accept Router Advertisements even if
> >   forwarding is enabled.
> >
> > Functional default:
> >
> > - enabled if local forwarding is disabled.
> > - disabled if local forwarding is enabled.

This appears to be a type of boolean that I wasn't previously familiar with -
one that has three different values.

If you don't have kernel version 2.6.37 though, like say, everyone running the
current Debian stable (2.6.32), this will not work. Helpfully, it also doesn't
give you any sort of error when you set accept_ra to "2". It just sets it and
continues silently ignoring router advertisements.

![fuuuuuuuuuuuuuuuuuuuuuu](images/fuu.jpg "fuuuuuuuuuuuuuuuuuuuuuu")

Fortunately
[Bjørn Mork posted about a workaround](http://lists.debian.org/debian-ipv6/2011/05/msg00046.html)
for earlier kernels which I would likely have never discovered otherwise. You
just have to disable forwarding for the interface that your router
advertisements will come in on, e.g.:

```
# echo 0 > /proc/sys/net/ipv6/conf/eth0/forwarding

```

Apparently as long as `/proc/sys/net/ipv6/conf/all/forwarding` is still set to
`1` then forwarding will still be enabled. Obviously.

Additionally there are some extremely unintuitive interactions between
`default` and `all` settings you may set in **/etc/sysctl.conf** and
pre-existing interfaces. So there is a race condition on boot between IPv6
interfaces coming up and sysctl configuration being parsed. martin f krafft
[posted about this](http://marc.info/?l=linux-kernel&m=123599691025508&w=2),
and on Debian recommends setting desired sysctls in pre-up headers of the
relevant iface stanza in **/etc/network/interfaces**, e.g.:

```txt
iface eth0 inet6 static
    address 2001:0db8:10c0:d0c5::1
    netmask 64
# Enable forwarding
    pre-up echo 1 > /proc/sys/net/ipv6/conf/default/forwarding
    pre-up echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
# But disable forwarding on THIS interface so we still get RAs
    pre-up echo 0 > /proc/sys/net/ipv6/conf/$IFACE/forwarding
    pre-up echo 1 > /proc/sys/net/ipv6/conf/$IFACE/accept_ra
    pre-up echo 1 > /proc/sys/net/ipv6/conf/all/accept_ra
    pre-up echo 1 > /proc/sys/net/ipv6/conf/default/accept_ra

```

You will now have forwarding _and_ SLAAC.

![everything went better than expected](images/ewbte.png "Everything went better than expected")
