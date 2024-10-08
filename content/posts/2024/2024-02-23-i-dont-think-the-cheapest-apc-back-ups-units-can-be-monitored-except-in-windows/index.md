+++
title = """
I don't think the cheapest APC Back-UPS units can be monitored except in
Windows
"""
description = """
Despite otherwise seeming to work correctly, I can't monitor a Back-UPS
BX1600MI in Linux without seeing a constant stream of spurious battery
detach/reattach and power fail/restore events that last less than 2 seconds
each. I've tried multiple computers and multiple UPSes of that model. It
doesn't happen in their own proprietary Windows software, so I think
they've changed the protocol.
"""

[taxonomies]
tags = [
    "apc",
    "fail",
    "hardware",
    "linux",
    "ups",
    "migrated-from-wordpress",
]

[extra]
hide_from_feed = true
+++

{% admonition_body(type="note", title="Workaround in nut!") %}

There may now be a workaround in `nut`! On 11 August 2024 based on [the issue
I reported][nut-issue], [a PR][nut-pr] was merged to add options to filter out
these spurious events. I now run `nut` without any problems.

[nut-issue]: https://github.com/networkupstools/nut/issues/2347
[nut-pr]: https://github.com/networkupstools/nut/pull/2565

I'll leave this post here unchanged so that search engines can still find it
for other people having the same issues, as APC surely won't document this.

{% end %}

{% admonition_body(type="info", title="TL;DR:") %}

Despite otherwise seeming to work correctly, I can't monitor a Back-UPS
BX1600MI in Linux without seeing a constant stream of spurious battery
detach/reattach and power fail/restore events that last less than 2 seconds
each. I've tried multiple computers and multiple UPSes of that model. It
doesn't happen in their own proprietary Windows software, so I think they've
changed the protocol.

{% end %}

Apart from nearly two decades ago when I was given one for free, I've never
bothered with a UPS at home. Our power grid is very reliable. Looking at
availability information from [`uptimed`][uptimed], my home file server has
been powered on for 99.97% of the time in the last 14 years. That includes
time spent moving house and a day when the house power was off for several
hours while the kitchen was refitted!

[uptimed]: https://github.com/rpodgorny/uptimed

However, in December 2023 a fault with our electric oven popped the breaker
for the sockets causing everything to be harshly powered off. My file server
took it badly and one drive died. That wasn't a huge issue as it has a
redundant filesystem, but I didn't like it.

I decided I could afford to treat myself to a relatively cheap UPS.

I did some research and read some reviews of the [APC Back-UPS
range][apc-back-ups], their cheapest offering. Many people were dismissive
calling them cheap pieces of crap with flimsy plastic construction and
batteries that are not regarded as user-replaceable. But there was no
indication that such a model would not work, and I felt it hard to justify
paying a lot here.

[apc-back-ups]:
  https://www.apc.com/uk/en/product/BX1600MI/apc-backups-1600va-tower-230v-6x-iec-c13-outlets-avr/?%3Frange=61883-backups&selectedNodeId=27590290410

I found YouTube videos of the procedure that a technician would go through to
replace the battery in 3 to 5 years. To do it yourself voids your warranty,
but your warranty is done after 3 years anyway. It looked pretty doable even
for a hardware-avoidant person like myself.

It's important to me that the UPS can be monitored by a Linux computer. The
entire point here is that the computer detects when the battery is near to
exhausted and gracefully powers itself down. There are two main options on
Linux for this: [`apcupsd`][apcupsd] and [Network UPS Tools][nut] ("`nut`").

[apcupsd]: http://www.apcupsd.org/
[nut]: https://networkupstools.org/index.html

Looking at the Back-UPS BX1600MI model, it has a USB port for monitoring and
says it can be monitored with APC's own Powerchute Serial Shutdown Windows
software. There's an entry in `nut`'s hardware compatibility list for
"Back-UPS (USB)" of "supported, based on publicly available protocol". I made
the order.

The UPS worked as expected in terms of being an uninterruptible power supply.
It was initially hopeless trying to talk to it with `nut` though. `nut` just
kept saying it was losing communications.

I tried `apcupsd` instead. This stayed connected, but it showed a continuous
stream of battery detach/reattach and power fail/restore events each lasting
less than 2 seconds. Normally on a power fail you'd expect a visual and
audible alert on the UPS itself and I wasn't getting any of that, but I don't
know if that's because they were real events that were just too brief.

I contacted APC support but they were very quick to tell me that they did not
support any other software but their own Windows-only Powerchute Serial
Shutdown (PCSS).

I then asked about this on the `apcupsd` mailing list. The first response:

> "Something's wrong with your UPS, most likely the battery is bad, but since
> you say the UPS is brand new, just get it replaced."

As this thing was brand new I wasn't going to go through a warranty claim with
APC. I just contacted the retailer and told them I thought it was faulty and I
wanted to return it. They actually offered to send me another one in advance
and me send back the one I had, so I went for that.

In the mean time I found time to install Windows 10 in a virtual machine and
pass through USB to it. Guess what? No spurious events in PCSS on Windows. It
detected expected events when I yanked the power etc. I had no evidence that
the UPS was in any way faulty. You can probably see what is coming.

The replacement UPS (of the same model, APC Bacxk-UPS BX1600MI) behaved
exactly the same: spurious events. This just seems to be what the APC Back-UPS
_does_ on non-Windows.

Returning to my thread on the `apcupsd` mailing list, I asked again if there
was actually anyone out there who had one of these working with non-Windows.
The only substantive response I've got so far is:

> "BX are the El Cheapo plastic craps, worst of all, not even the BExx0 family
> is such a crap - Schneider's direct response to all the chinese craps
> flooding the markets \[…\] no sane person would buy these things, but, well,
> here we are."

So as far as I am aware, the Back-UPS models cannot currently be monitored
from non-Windows. That will have to be my working theory unless someone who
has it working with non-Windows contacts me to let me know I am wrong, which I
would be interested to know about. I feel like I've done all that I can to
find such people, by asking on the mailing list for the software that is meant
for monitoring APC UPSes on Unix.

After talking all this over with the retailer they've recommended a [Riello
NPW 1.5kVA][riello-npw] which is [listed as fully supported by
`nut`][nut-riello]. They are taking the APC units back for a full refund; the
Riello is about £30 more expensive.

[riello-npw]: https://www.riello-ups.co.uk/products/1-ups/63-net-power
[nut-riello]:
  https://networkupstools.org/stable-hcl.html?manufacturer=Riello&model=NPW%20600/800/1000/1500/2000
