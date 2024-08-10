+++
title = "Keeping firewall logs out of Linux's kernel log with ulogd2"
description = """
Logging rules in your Linux firewall send logs to your kernel log, /dev/kmsg,
which is a fixed size circular buffer, so after a while your firewall logs will
crowd out every other thing. Here's how I keep such logs out of the kernel.
"""

[taxonomies]
tags = [
    "iptables",
    "linux",
    "migrated-from-wordpress",
]

[extra]
hide_from_feed = true
+++

{{ toc() }}

## A few words about `iptables` vs `nft`

[nftables][nftables] is the new thing and `iptables` is deprecated, but I
haven't found time to convert everything to `nft` rules syntax yet.

[nftables]: https://wiki.nftables.org/wiki-nftables/index.php/Main_Page

I'm still using `iptables` rules but it's the `iptables` frontend to nftables.
All of this works both with legacy `iptables` and with `nft` but with
different syntax.

## Logging with `iptables`

As a contrived example let's log inbound ICMP packets at a maximum rate of 1
per second:

```txt
-A INPUT -m limit --limit 1/s -p icmp -j LOG --log-level 7 --log-prefix "ICMP: "
```

## The Problem

If you have logging rules in your firewall then they'll log to your kernel
log, which is available at **/dev/kmsg**. The `dmesg` command displays the
contents of **/dev/kmsg** but **/dev/kmsg** is a fixed size circular buffer,
so after a while your firewall logs will crowd out every other thing.

On a modern systemd system this stuff _does_ get copied to the journal, so if
you set that to be persistent then you can keep the kernel logs forever. Or
you can additionally run a syslog daemon like `rsyslogd`, and have that keep
things forever.

Either way though your `dmesg` or `journalctl -k` commands are only going to
display the contents of the kernel's ring buffer which will be a limited
amount.

I'm not that interested in firewall logs. They're nice to have and very
occasionally valuable when debugging something, but most of the time I'd
rather they weren't in my kernel log.

## An answer: `ulogd2`

One answer to this problem is [`ulogd2`][ulogd2]. `ulogd2` is a userspace
logging daemon into which you can feed netfilter data and have it log it in a
flexible way, to multiple different formats and destinations.

[ulogd2]: https://www.netfilter.org/projects/ulogd/

I actually already use it to log certain firewall things to a MariaDB database
for monitoring purposes, but you can also emit plain text, JSON, netflow and
all manner of things. Since I'm already running it I decided to switch my
general firewall logging to it.

### Configuring `ulogd2`

I added the following to **/etc/ulogd.conf**:

```txt
# This one for logging to local file in emulated syslog format.
stack=log2:NFLOG,base1:BASE,ifi1:IFINDEX,ip2str1:IP2STR,print1:PRINTPKT,emu1:LOGEMU

[log2]
group=2

[emu1]
file="/var/log/iptables_ulogd2.log"
sync=1
```

I already had a `stack` called `log1` for logging to MariaDB, so I called the
new one `log2` with its output being `emu1`.

The `log2` section can then be told to expect messages from netfilter group 2.
Don't worry about this, just know that this is what you refer to in your
firewall rules, and you can't use group 0 because that's used for something
else.

The `emu1` section then says which file to write this stuff to.

That's it. Restart the daemon.

### Configuring `iptables`

Now it's time to make `iptables` log to netfilter group 2 instead of its
normal `LOG` target. As a reminder, here's what the rule was like before:

```txt
-A INPUT -m limit --limit 1/s -p icmp -j LOG --log-level 7 --log-prefix "ICMP: "
```

And here's what you'd change it to:

```txt
-A INPUT -m limit --limit 1/s -p icmp -j NFLOG --nflog-group 2 --nflog-prefix "ICMP:"
```

The `--nflog-group 2` needs to match what you put in **/etc/ulogd.conf**.

You're now logging with `ulogd2` and none of this will be going to the kernel
log buffer. Don't forget to rotate the new log file! Or maybe you'd like to
play with logging this as JSON or into a [SQLite][sqlite] DB?

[sqlite]: https://www.sqlite.org/
