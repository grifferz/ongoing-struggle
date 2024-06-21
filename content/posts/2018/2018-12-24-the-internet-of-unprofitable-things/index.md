+++
title = "The Internet of Unprofitable Things"
description = """
Gather 'round children. Uncle Andrew wants to tell you a festive story. The
NTPmare shortly after Christmas
"""

[taxonomies]
tags = [
    "bitfolk",
    "fail",
    "iot",
    "migrated-from-wordpress",
]

[extra]
# On the basis that this was already published and doesn't need to be fed out
# again…
hide_from_feed = true
+++

## Gather 'round children

Uncle Andrew wants to tell you a festive story. The NTPmare shortly after
Christmas.

## A modest proposal

Nearly two years ago, on the afternoon of Monday 16th January 2017, I received
an interesting [BitFolk](https://bitfolk.com/) support ticket from a
non-customer. The sender identified themselves as a senior software engineer
at NetThings UK Ltd.

> Subject: Specific request for NTP on IP `85.119.80.232`
>
> Hi,
>
> This might sound odd but I need to setup an NTP server instance on IP
> address `85.119.80.232`.

## wats `85.119.80.232` precious?

`85.119.80.232` is actually one of the IP addresses of one of BitFolk's
customer-facing NTP servers. It was also, until a few weeks before this email,
part of [the NTP Pool project](https://www.ntppool.org/).

"_Was_" being the important issue here. In late December of 2016 I had
withdrawn BitFolk's NTP servers from the public pool and firewalled them off
to non-customers.

I'd done that because they were receiving an unusually large amount of traffic
due to
[the Snapchat NTP bug](https://en.wikipedia.org/wiki/NTP_server_misuse_and_abuse#Snapchat_on_iOS).
It wasn't really causing any huge problems, but the number of traffic flows
were pushing useful information out of [Jump](http://www.jump.net.uk/)'s
fixed-size netflow database and I didn't want to deal with it over the holiday
period, so this public service was withdrawn.

## NTP?

This article was
[posted to Hacker News](https://news.ycombinator.com/item?id=18751771) and a
couple of comments there said they would have liked to have seen a brief
explanation of what NTP is, so I've now added this section. If you know what
NTP is already then you should probably skip this section because it will be
quite brief and non-technical.

Network Time Protocol is a means by which a computer can use multiple other
computers, often from across the Internet on completely different networks
under different administrative control, to accurately determine what the
current time is. By using several different computers, a small number of them
can be inaccurate or even downright broken or hostile, and still the protocol
can detect the "bad" clocks and only take into account the more accurate
majority.

NTP is supposed to be used in a hierarchical fashion: A small number of
servers have hardware directly attached from which they can very accurately
tell the time, e.g. an atomic clock, GPS, etc. Those are called "Stratum 1"
servers. A larger number of servers use the stratum 1 servers to set their own
time, then serve that time to a much larger population of clients, and so on.

It used to be the case that it was quite hard to find NTP servers that you
were allowed to use. Your own organisation might have one or two, but really
you should have at least 3 to 7 of them and it's better if there are multiple
different organisations involved. In a university environment that wasn't so
difficult because you could speak to colleagues from another institution and
swap NTP access. As the Internet matured and became majority used by
corporations and private individuals though, people still needed access to
accurate time, and this wasn't going to cut it.

The NTP Pool project came to the rescue by making an easy web interface for
people to volunteer their NTP servers, and then they'd be served collectively
in a DNS zone with some basic means to share load. A private individual can
just use three names from the pool zone and they will get three different
(constantly changing) NTP servers.

Corporations and those making products that need to query the NTP pool are
supposed to ask for a "vendor zone". They make some small contribution to the
NTP pool project and then they get a DNS zone dedicated to their product, so
it's easier for the pool administrators to direct the traffic.

Sadly many companies don't take the time to understand this and just use the
generic pool zone. NetThings UK Ltd went one step further in a very wrong
direction by taking an IP address from the pool and just using it directly,
assuming it would always be available for their use. In reality it was a free
service donated to the pool by BitFolk and as it had become temporarily
inconvenient for that arrangement to continue, service was withdrawn.

On with the story…

## They want what?

The Senior Software Engineer continued:

> The NTP service was recently shutdown and I am interested to know if there
> is any possibility of starting it up again on the IP address mentioned.
> Either through the current holder of the IP address or through the migration
> of the current machine to another address to enable us to lease
> `85.119.80.232`.

Um…

> I realise that this is a peculiar request but I can assure you it is
> genuine.

## That's not gonna work

Obviously what with `85.119.80.232` currently being in use by all customers as
a resolver and NTP server I wasn't very interested in getting them all to
change their configuration and then leasing it to NetThings UK Ltd.

What I did was remove the firewalling so that `85.119.80.232` still worked as
an NTP server for NetThings UK Ltd until we worked out what could be done.

I then asked some pertinent questions so we could work out the scope of the
service we'd need to provide. Questions such as:

- How many clients do you have using this?
- Do you know their IP addresses?
- When do they need to use the NTP server and for how long?
- Can you make them use the pool properly (a vendor zone)?

## Down the rabbit hole

The answers to some of the above questions were quite disappointing.

> It would be of some use for our manufacturing setup (where the RTCs are
> initially set) but unfortunately we also have a reasonably large field
> population (~500 units with weekly NTP calls) that use roaming GPRS SIMs. I
> don't know if we can rely on the source IP of the APN for configuring the
> firewall in this case (I will check though). We are also unable to update
> the firmware remotely on these devices as they only have a 5MB per month
> data allowance. We are able to wirelessly update them locally but the
> timeline for this is months rather than weeks.

Basically it seemed that NetThings UK Ltd made remote controlled thermostats
and lighting controllers for large retail spaces etc. And their devices had
one of BitFolk's IP addresses burnt into them at the factory. And they could
not be identified or remotely updated.

![Facepalm](images/computer-facepalm.gif "An animated GIF of IT Crowd Roy reading something on this computer screen and then face-palming")

Oh, and whatever these devices were, without an external time source their
clocks would start to noticeably drift within 2 weeks.

By the way, they solved their "burnt into it at the factory" problem by
_bringing up BitFolk's IP address locally at their factory_ to set initial
date/time.

![Group Facepalm](images/Weird_Science_Facepalm_01.gif "An animated GIF of a sports hall full of athletes who all face-palm and fall over backwards in unison")

I'll admit, at this point I was slightly tempted to work out how to identify
these devices and reply to them with completely the wrong times to see if I
could get some retail parks to turn their lights on and off at strange times.

## Weekly??

> We are triggering ntp calls on a weekly cron with no client side load
> balancing. This would result in a flood of calls at the same time every
> Sunday evening at around 19:45.

Yeah, they made every single one of their unidentifiable devices contact a
hard coded IP address within a two minute window every Sunday night.

![](images/kbh.gif "An animated GIF of a child going down a slide wobbling from side to side and bashing their head off the edges all the way down")

The Senior Software Engineer was initially very worried that they were the
cause of the excess flows I had mentioned earlier, but I reassured them that
it was definitely the Snapchat bug. In fact I never was able to detect their
devices above background noise; it turns out that ~500 devices doing a single
SNTP query is pretty light load. They'd been doing it for over 2 years before
I received this email.

I did of course point out that they were lucky we caught this early because
they could have ended up as the next
[Netgear _vs_. University of Wisconsin](https://en.wikipedia.org/wiki/NTP_server_misuse_and_abuse#Netgear_and_the_University_of_Wisconsin%E2%80%93Madison).

> I am feeling really, really bad about this. I'm very, very sorry if we were
> the cause of your problems.

Bless. I must point out that throughout all of this, their Senior Software
Engineer was a pleasure to work with.

## We made a deal

While NTP service is something BitFolk provides as a courtesy to customers,
it's not something that I wanted to sell as a service on its own. And after
all, who would buy it, when the public pool exists? The correct thing for a
corporate entity to do is support the pool with a vendor zone.

But NetThings UK Ltd were in a bind and not allowing them to use BitFolk's NTP
server was going to cause them great commercial harm. Potentially I could have
asked for a lot of money at this point, but (no doubt to my detriment) that
just felt wrong.

I proposed that initially they pay me for two hours of consultancy to cover
work already done in dealing with their request and making the firewall
changes.

I further proposed that I charged them one hour of consultancy per month for a
period of 12 months, to cover continued operation of the NTP server. Of
course, I do not spend an hour a month fiddling with NTP, but this unusual
departure from my normal business had to come at some cost.

I was keen to point out that this wasn't something I wanted to continue
forever:

> Finally, this is not a punitive charge. It seems likely that you are in a
> difficult position at the moment and there is the temptation to charge you
> as much as we can get away with (a lot more than £840 \[+VAT per year\],
> anyway), but this seems unfair to me. However, providing NTP service to
> third parties is not a business we want to be in so we would expect this to
> only last around 12 months. If you end up having to renew this service after
> 12 months then that would be an indication that we haven't charged you
> enough and we will increase the price.
>
> Does this seem reasonable?

NetThings UK Ltd happily agreed to this proposal on a quarterly basis.

> Thanks again for the info and help. You have saved me a huge amount of
> convoluted and throwaway work. This give us enough time to fix things
> properly.

## Not plain sailing

I only communicated with the Senior Software Engineer one more time. The rest
of the correspondence was with financial staff, mainly because NetThings UK
Ltd did not like paying its bills on time.

NetThings UK Ltd paid 3 of its 4 invoices in the first year late. I made sure
to charge them
[statutory late payment fees](http://payontime.co.uk/late-payment-legislation-interest-calculators)
for each overdue invoice.

## Yearly report card: must try harder

As 2017 was drawing to a close, I asked the Senior Software Engineer how
NetThings UK Ltd was getting on with ceasing to hard code BitFolk's IP address
in its products.

> To give you a quick summary, we have migrated the majority of our products
> away from using the fixed IP address. There is still one project to be
> updated after which there will be no new units being manufactured using the
> fixed IP address. However, we still have around 1000 units out in the field
> that are not readily updatable and will continue to perform weekly NTP calls
> to the fixed IP address. So to answer your question, yes we will still
> require the service past January 2018.

This was a bit disappointing because a year earlier the number had been "about
500" devices, yet despite a year of effort the number had apparently doubled.

That alone would have been enough for me to increase the charge, but I was
going to anyway due to NetThings UK Ltd's aversion to paying on time. I gave
them just over 2 months of notice that the price was going to double.

## u wot m8

Approximately 15 weeks after being told that the price doubling was going to
happen, NetThings UK Ltd's Financial Controller asked me why it had happened,
while letting me know that another of their late payments had been made:

> Date: Wed, 21 Feb 2018 14:59:42 +0000
>
> We've paid this now, but can you explain why the price has doubled?

I was very happy to explain again in detail why it had doubled. The Financial
Controller in response tried to agree a fixed price for a year, which I said I
would be happy to do if they paid for the full year in one payment.

My rationale for this was that a large part of the reason for the increase was
that I had been spending a lot of time chasing their late payments, so if they
wanted to still make quarterly payments then I would need the opportunity to
charge more if I needed to. If they wanted assurance then in my view they
should pay for it by making one yearly payment.

There was no reply, so the arrangement continued on a quarterly basis.

## All good things…

On 20 November 2018 BitFolk received a letter from
[Deloitte](https://deloitte.com/):

> **Netthings Limited - In Administration ("The Company")**
>
> **Company Number: SC313913**
>
> \[…\]
>
> **Cessation of Trading**
>
> The Company ceased to trade with effect from 15 November 2018.
>
> **Investigation**
>
> As part of our duties as Joint Administrators, we shall be investigating
> what assets the Company holds and what recoveries if any may be made for the
> benefit of creditors as well as the manner in which the Company's business
> has been conducted.

And then on 21 December:

> Under paragraph 51(1)(b) of the Insolvency Act 1986, the Joint
> Administrators are not required to call an initial creditors' meeting unless
> the Company has sufficient funds to make a distribution to the unsecured
> creditors, or unless a meeting is requested on Form SADM_127 by 10% or more
> in value of the Company's unsecured creditors. **There will be no funds
> available to make a distribution to the unsecured creditors of the Company,
> therefore a creditors' meeting will not be convened.**

Luckily their only unpaid invoice was for service from some point in November,
so they didn't really get anything that they hadn't already paid for.

So that's the story of NetThings UK Ltd, a brave pioneer of the Internet of
Things wave, who thought that the public NTP pool was just an inherent part of
the Internet that anyone could use for free, and that the way to do that was
to pick one IP address out of it at random and bake that into over a thousand
bits of hardware that they distributed around the country with no way to
remotely update.

This coupled with their innovative reluctance to pay for anything on time was
sadly not enough to let them remain solvent.
