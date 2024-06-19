+++
title = "Farewell Soekris, old friend"
description = """
This morning I shut off the Soekris Engineering net4801 that has served as our
home firewall / PPP termination box for just over 18½ years
"""

[taxonomies]
tags = [
  "debian",
  "hacking",
  "hardware",
  "linux",
  "migrated-from-wordpress",
  "personal",
  "toys",
]

[extra]
hide_from_feed = true
+++

This morning I shut off the
[Soekris Engineering net4801](http://www.soekris.com/media/manuals/net4801_manual.pdf)
that has served as our home firewall / PPP termination box for just over 18½
years.

{{ figure(
    class="captioned"
    src="images/net4801_front.jpg",
    alt="Front view of a Soekris net4801",
    caption="Front view of a Soekris net4801. Clothes peg for scale."
) }}

{{ figure(
    class="captioned"
    src="images/net4801_inside.jpg",
    alt="Inside of a Soekris net4801",
    caption="Inside of a Soekris net4801."
) }}

In truth this has been long overdue. Like,
[at least 10 years overdue](https://strugglers.net/~andy/blog/2013/09/03/wanted-cheap-but-cheerful-small-linux-device/).
It has been struggling to cope with even our paltry ~60Mbps VDSL (what UK
calls Fibre to the Cabinet). But I am very lazy, and change is work.

In theory we can get fibre from Openreach to approach 1Gbit/s down, and I
should sort that out, but see above about me being really very lazy. The poor
old Soekris would certainly not be viable then.

I've replaced it with a [PC Engines APU2](https://www.pcengines.ch/apu2e2.htm)
(the apu2e2 model). Much like the Soekris it's a fanless single board x86
computer with coreboot firmware so it's manageable from the BIOS over serial.

{{ figure(
    class="captioned"
    src="images/apu2e2_1.jpg",
    alt="An apu2e2 single board computer",
    caption="An apu2e2 single board computer, image copyright PC Engines GmbH."
) }}

{{ figure(
    class="captioned"
    src="images/case1d2redu.jpg",
    alt="Rear view of an APU2 case1d2redu",
    caption="Rear view of an APU2 case1d2redu, image copyright PC Engines
        GmbH."
) }}

{{ figure(
    class="captioned"
    src="images/case1d2redu2.jpg",
    alt="Front view of an APU2 case1d2redu",
    caption="Front view of an APU2 case1d2redu, image copyright PC Engines
        GmbH."
) }}

{{ figure(
    class="captioned"
    src="images/case1d2redu3.jpg",
    alt="An APU2 case1d2redu, top and bottom halves separated",
    caption="An APU2 case1d2redu, top and bottom halves separated, image
        copyright PC Engines GmbH."
) }}

|         | Soekris net4801                           | PC Engines apu2e2                                              |
| ------- | ----------------------------------------- | -------------------------------------------------------------- |
| CPU     | AMD GX1<br>1 core @266MHz<br>x86 (32-bit) | AMD GX-412TC<br>4 cores @1GHz (turbo 1.4GHz)<br>amd64 (64-bit) |
| Memory  | 128MiB                                    | 2048MiB                                                        |
| Storage | 512MiB CompactFlash                       | 16GiB mSATA SSD                                                |
| Ports   | 3x 100M Ethernet, 1 serial                | 3x 1G Ethernet, 1 serial                                       |

The Soekris ran Debian and so does the APU2. Installing it over PXE was
completely straightforward on the APU2; a bit
[simpler than it was with the net4801 back in 2005](https://strugglers.net/wiki/Debian_on_Soekris)!
If you have just one and it's right there in the same building then it's
probably quicker to just boot the Debian installer off of USB though. I may be
lazy but once I do get going I'm also pointlessly bloody-minded.

Anyway, completely stock Debian works fine, though obviously it has no display
whatsoever — all non-Ethernet-based interaction would have to be done over
serial. By default that runs at 115200 baud (8n1).

This is not "home server" material. Like the Soekris even in 2005 it's weak
and it's expensive for what it is. It's meant to be an appliance. I think I
was right with the Soekris's endurance, beyond even sensible limits, and I
hope I will be right about the APU2.

The Soekris is still using its original 512M CompactFlash card from 2005 by
the way. Although admittedly I did go to some effort to make it run on a
read-only filesystem, only flipped to read-write for upgrades.
