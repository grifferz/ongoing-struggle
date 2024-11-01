+++
title = "Protecting URIs from Tor nodes with the Apache HTTP Server"
description = """
How to block requests from Tor nodes to certain URIs with the Apache HTTP Server
"""

[taxonomies]
tags = [
    "apache",
    "tor",
]

[extra]
+++

Recently I found one of my web services under attack from clients using [Tor].

[Tor]: https://en.wikipedia.org/wiki/Tor_(network)

For the most part I am okay with the existence of Tor, but if you're being
attacked largely or exclusively through Tor then you might need to take
actions like:

- Temporarily or permanently blocking access entirely.
- Taking away access to certain privileged functions.

Here's how I did it.

{{ toc() }}

## Step 1: Obtain a list of exit nodes

Tor exit nodes are the last hop before reaching regular Internet services, so
traffic coming through Tor will always have a source IP of an exit node.

Happily there are quite a few services that list Tor nodes. I like
[https://www.dan.me.uk/tornodes](https://www.dan.me.uk/tornodes) which can
provide a list of exit nodes, updated hourly.

This comes as a list of IP addresses one per line so in order to turn it into
an httpd access control list:

```txt
$ curl -s 'https://www.dan.me.uk/torlist/?exit' |
    sed 's/^/Require not ip /' |
    sudo tee /etc/apache2/tor-exit-list.conf >/dev/null
```

This results in a file like:

```txt
$ head -10 /etc/apache2/tor-exit-list.conf
Require not ip 102.130.113.9
Require not ip 102.130.117.167
Require not ip 102.130.127.117
Require not ip 103.109.101.105
Require not ip 103.126.161.54
Require not ip 103.163.218.11
Require not ip 103.164.54.199
Require not ip 103.196.37.111
Require not ip 103.208.86.5
Require not ip 103.229.54.107
```

## Step 2: Configure httpd to block them

Totally blocking traffic from these IPs would be easier than what I decided to
do. If you just wanted to totally block traffic from Tor then the easy and
efficient answer would be to insert all these IPs into an [nftables set] or an
[iptables IP set].

[nftables set]: https://wiki.nftables.org/wiki-nftables/index.php/Sets
[iptables IP set]: https://ipset.netfilter.org/

For me, it's only some URIs on my web service that I don't want these IPs
accessing and I wanted to preserve the ability of Tor's non-abusive users to
otherwise use the rest of the service. An httpd access control configuration
is necessary.

Inside the virtualhost configuration file I added:

```txt
    <Location /some/sensitive/thing>
        <RequireAll>
            Require all granted
            Include /etc/apache2/tor-exit-list.conf
        </RequireAll>
    </Location>
```

## Step 3: Test configuration and reload

It's a good idea to check the correctness of the httpd configuration now.
Aside from syntax errors in the list of IP addresses, this might catch if you
forgot any modules necessary for these directives. Although I think they are
all pretty core.

Assuming all is well then a graceful reload will be needed to make httpd see
the new configuration.

```txt
$ sudo apache2ctl configtest
Syntax OK
$ sudo apache2ctl graceful
```

## Step 4: Further improvements

Things can't be left there, but I haven't got around to any of this yet.

1. Script the repeated download of the Tor exit node list. The list of active
   Tor nodes will change over time.
1. Develop some checks on the list such as:
   1. Does it contain only valid IP addresses?
   1. Does it contain at least _min_ number of addresses and less than _max_
      number?
1. If the list changed, do the config test and reload again. httpd will not
   include the altered config file without a reload.
1. If the list has not changed in _x_ number of days, consider the data source
   stale and think about emptying the list.

## Performance thoughts

I have not checked how much this impacts performance. My service is not under
enough load for this to be noticeable for me.

At the moment the Tor exit node list is around 2,100 addresses and I don't
know how efficient the Apache HTTP Server is about a large list of
`Require not ip` directives. Worst case is that for every request to that URI
it will be scanning sequentially through to the end of the list.

I think that using httpd's [support for DBM files] in `RewriteMap`s might be quite
efficient but this comes with the significant issue that IPv6 addresses have multiple
formats, while a DBM lookup will be doing a literal text comparison.

[support for DBM files]:
  https://httpd.apache.org/docs/current/rewrite/rewritemap.html#dbm

For example, all of the following represent the same IPv6 address:

- 2001:db8::
- 2001:0DB8::
- 2001:Db8:0000:0000:0000:0000:0000:0000
- 2001:db8:0:0:0:0:0:0

httpd does have built-in functions to upper- or lower-case things, but not to
compress or expand an IPv6 address. httpd access control directives are also
able to match the request IP against a CIDR net block, although at the moment
Dan's Tor node list does only contain individual IP addresses. At a later date
one might like to try to aggregate those individual IP addresses into larger
blocks.

httpd's `RewriteMap`s can also [query an SQL server]. Querying a competent database
implementation like [PostgreSQL] could be made to alleviate some of those concerns
if the data were represented properly, though this does start to seem like an awful
lot of work just for an access control list!

[query an SQL server]:
  https://httpd.apache.org/docs/current/rewrite/rewritemap.html#dbd
[PostgreSQL]: https://www.postgresql.org/docs/current/datatype-net-types.html

Over on [Fedi], it was suggested that a firewall rule — presumably using an
nftables set or iptables IP set, which are very efficient — could redirect
matching source IPs to a separate web server on a different port, which would
then do the URI matching as necessary.

[Fedi]: https://social.kern.pm/@phil/113401410429414244

`<nerdsnipe>`There does not seem to be an Apache HTTP Server authz module for
IP sets. That would be the best of both worlds!`</nerdsnipe>`
