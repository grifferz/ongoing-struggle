+++
title = "Check yo PTRs"
# No date needed because filename or containing directory should be of the
# form YYYY-MM-DD-slug and Zola can work it out from that.
description = """
After being irritated that I kept forgetting to set sensible reverse DNS I
wrote a thing to remind me to do so
"""

[taxonomies]
# see `docs/tags_in_use.md` for a list of all tags currently in use.
tags = [
    "dns",
    "hacking",
    "rustlang",
]

+++

## Backstory

The other day I was looking through a log file and saw one of [BitFolk]'s IP
addresses doing something. I didn't recognise the address so I did a reverse
lookup and got `2001-ba8-1f1-f284-0-0-0-2.autov6rev.bitfolk.space` — which is
a generic setting and not very useful.

[BitFolk]: https://bitfolk.com/

It's quick to look this up and fix it of course, but I wondered how many other
such addresses I had forgotten to take care of the reverse DNS for.

## ptrcheck

In order to answer that question, automatically and in bulk, I wrote
[ptrcheck].

[ptrcheck]: https://github.com/grifferz/ptrcheck-rs

It was able to tell me that almost all of my domains had at least one
reference to something without a suitable PTR record.

<svg width="631.43" height="221.43" xmlns="http://www.w3.org/2000/svg">
<rect width="631.43" height="221.43" fill="#171717" rx="8.00" ry="8.00" x="0.00px" y="0.00px"/>
<g font-family="monospace" font-size="20.00px" fill="#c4c4c4" clip-path="url(#terminalMask)">
<text x="20.00px" y="59.00px" xml:space="preserve"><tspan xml:space="preserve">$ ptrcheck --server [::1] --zone strugglers.net</tspan></text><text x="20.00px" y="83.00px" xml:space="preserve"><tspan xml:space="preserve" fill="#00FEFE">➡ 192.168.9.10 is pointed to by:</tspan></text><text x="20.00px" y="107.00px" xml:space="preserve"><tspan xml:space="preserve">    intentionally-broken.strugglers.net.</tspan></text><text x="20.00px" y="131.00px" xml:space="preserve"><tspan xml:space="preserve">    </tspan><tspan xml:space="preserve" fill="#FE5F86">Missing PTR for </tspan><tspan xml:space="preserve" fill="#04D7D7">192.168.9.10</tspan></text><text x="20.00px" y="155.00px" xml:space="preserve"><tspan xml:space="preserve"/><tspan xml:space="preserve" dx="4.00px">
   </tspan><tspan xml:space="preserve" fill="#FE5F86">1 missing/broken PTR record</tspan></text><text x="20.00px" y="179.00px" xml:space="preserve"><tspan xml:space="preserve">$</tspan></text>
</g>
<svg x="0.00px" y="0.00px"><circle cx="13.50" cy="12.00" r="5.50" fill="#FF5A54"/><circle cx="32.50" cy="12.00" r="5.50" fill="#E6BF29"/><circle cx="51.50" cy="12.00" r="5.50" fill="#52C12B"/></svg></svg>

Though it wasn't _all_ bad news. 😀

<svg width="786.19" height="510.00" xmlns="http://www.w3.org/2000/svg">
<rect width="786.19" height="510.00" fill="#171717" rx="8.00" ry="8.00" x="0.00px" y="0.00px"/>
<g font-family="monospace" font-size="20.00px" fill="#c4c4c4" clip-path="url(#terminalMask)">
<text x="20.00px" y="59.00px" xml:space="preserve"><tspan xml:space="preserve">$ ptrcheck --server [::1] --zone dogsitter.services -v</tspan></text><text x="20.00px" y="83.00px" xml:space="preserve"><tspan xml:space="preserve">Connecting to </tspan><tspan xml:space="preserve" fill="#04D7D7">::1 port </tspan><tspan xml:space="preserve" fill="#04D7D7">53 for AXFR of zone </tspan><tspan xml:space="preserve" fill="#04D7D7">dogsitter.service</tspan></text><text x="20.00px" y="107.00px" xml:space="preserve"><tspan xml:space="preserve" fill="#04D7D7">s</tspan></text><text x="20.00px" y="131.00px" xml:space="preserve"><tspan xml:space="preserve">Zone contains </tspan><tspan xml:space="preserve" fill="#31BB71">57 records</tspan></text><text x="20.00px" y="155.00px" xml:space="preserve"><tspan xml:space="preserve">Found </tspan><tspan xml:space="preserve" fill="#31BB71">3 unique address (A/AAAA) records</tspan></text><text x="20.00px" y="179.00px" xml:space="preserve"><tspan xml:space="preserve" fill="#00FEFE">➡ 2001:ba8:1f1:f113::80 is pointed to by:</tspan></text><text x="20.00px" y="203.00px" xml:space="preserve"><tspan xml:space="preserve">    dogsitter.services., dev.dogsitter.services., www.dogsit</tspan></text><text x="20.00px" y="227.00px" xml:space="preserve"><tspan xml:space="preserve">ter.services.</tspan></text><text x="20.00px" y="251.00px" xml:space="preserve"><tspan xml:space="preserve">    </tspan><tspan xml:space="preserve" fill="#31BB71">Found PTR: www.dogsitter.services.</tspan></text><text x="20.00px" y="275.00px" xml:space="preserve"><tspan xml:space="preserve" fill="#00FEFE">➡ 85.119.84.147 is pointed to by:</tspan></text><text x="20.00px" y="299.00px" xml:space="preserve"><tspan xml:space="preserve">    dogsitter.services., dev.dogsitter.services., tom.dogsit</tspan></text><text x="20.00px" y="323.00px" xml:space="preserve"><tspan xml:space="preserve">ter.services., www.dogsitter.services.</tspan></text><text x="20.00px" y="347.00px" xml:space="preserve"><tspan xml:space="preserve">    </tspan><tspan xml:space="preserve" fill="#31BB71">Found PTR: dogsitter.services.</tspan></text><text x="20.00px" y="371.00px" xml:space="preserve"><tspan xml:space="preserve" fill="#00FEFE">➡ 2001:ba8:1f1:f113::2 is pointed to by:</tspan></text><text x="20.00px" y="395.00px" xml:space="preserve"><tspan xml:space="preserve">    tom.dogsitter.services.</tspan></text><text x="20.00px" y="419.00px" xml:space="preserve"><tspan xml:space="preserve">    </tspan><tspan xml:space="preserve" fill="#31BB71">Found PTR: tom.dogsitter.services.</tspan></text><text x="20.00px" y="443.00px" xml:space="preserve"><tspan xml:space="preserve"/><tspan xml:space="preserve" dx="4.00px">🏆 100.0% good PTRs! Good job!</tspan></text><text x="20.00px" y="467.00px" xml:space="preserve"><tspan xml:space="preserve">$</tspan></text>
</g>
<svg x="0.00px" y="0.00px"><circle cx="13.50" cy="12.00" r="5.50" fill="#FF5A54"/><circle cx="32.50" cy="12.00" r="5.50" fill="#E6BF29"/><circle cx="51.50" cy="12.00" r="5.50" fill="#52C12B"/></svg></svg>

### How it works

See [the repository] for full details, but briefly: `ptrcheck` does a zone transfer
of the zone you specify and keeps track of every address (`A` / `AAAA`) record.
It then does a `PTR` query for each unique address record to make sure it

[the repository]: https://github.com/grifferz/ptrcheck-rs/

1. exists
1. is "acceptable"

You can provide a regular expression for what you deem to be "unacceptable",
otherwise any `PTR` content at all is good enough.

> Why might a `PTR` record be "unacceptable"??

I am glad you asked.

A lot of hosting providers generate generic `PTR` records when the customer
doesn't set their own. They're not a lot better than having no `PTR` at all.

## Failure to comply is no longer an option (for me)

The program runs silently (unless you use `--verbose`) so I was able to make a
cron job that runs once a day and complains at me if any of my zones ever
refer to a missing or unacceptable `PTR` ever again!

By the way, I ran it against all BitFolk [customer zones]; 26.5% of them had at
least one missing or generic `PTR` record.

[customer zones]: https://tools.bitfolk.com/wiki/Secondary_DNS_service
