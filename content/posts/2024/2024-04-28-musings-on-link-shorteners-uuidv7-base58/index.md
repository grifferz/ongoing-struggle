+++
title = "Musings on link shorteners, UUIDv7, Base58, …"
description = """
Yesterday I started thinking about maybe learning some Rust and as part of that
I thought perhaps I might try to implement a link shortener
"""

[taxonomies]
tags = [
    "hacking", "internet", "linux", "migrated-from-wordpress", "rustlang"
]

[extra]
hide_from_feed = true
+++

Yesterday I started thinking about maybe learning some Rust and as part of
that I thought perhaps I might try to implement a link shortener.

{{ toc() }}

## Disclaimer

Now, clearly there are tons of existing commercial link shorteners, I'm not
interested in making a commercial link shortener since:

- I don't think I am capable of doing a great job of it.
- I think being a commercial success here would involve a lot of activity that
  I don't like.

There's also plenty of existing FOSS projects that implement a link shortener,
in almost every language you can think of. That's interesting from an
inspiration point of view but my goal here is to learn a little bit about Rust
so there's no point in just setting up someone else's project.

So anyway, point is, I'm not looking to make something commercially viable and
I don't think I can make something better than what exists. I'm just messing
about and trying to learn some things.

Seems like a good project to learn stuff - it can be very very simple, but
grow to include many different areas such as databases, REST API,
authentication and so on.

## On Procrasturbation

The correct thing to do at this point is to just get on with it. I should not
even be writing _this article_! I should be either doing paying work, life
admin, or messing about with my learning project.

As usual though, my life is a testament to not doing the correct thing. 😀
Charitably I'll say that I can't stop myself from planning how it _should_ be
done rather than just doing it. Realistically there is a lot of
procrastination in there too.

## So Many Open Questions

I hope I've made clear that this is a learning goal for me, so it follows that
I have a lot of open questions. If you came here looking for expert guidance
then you've come to the wrong place. If you have answers to my questions that
would be great though. And of the few assertions I do make, if you disagree
then I'd also like to hear that opinion.

## Thinking About Link Shorteners

### Is enumeration bad?

Obviously the entire point of a link shortener is to map short strings to long
ones. As a consequence the key space of short strings is quite easy to iterate
through and the pressure is always there to keep the space small as that's
what makes for appealing short links. Is this bad? If it is bad, how bad is it
and so how much should the temptation to keep things short be resisted?

An extremely naive link shortener might just increment a counter (and perhaps
convert decimal digits to a string with more symbols so it's shorter). For
example:

- example.com/0
- example.com/1
- example.com/2
- …
- example.com/99
- example.com/100

That's great for the shortest keys possible but it's trivial for anyone in the
world to just iterate through every link in your database. Users will have an
expectation that links they shorten and do not show to anyone else remain
known only by them. People shorten links to private documents _all the time_.
But every guess results in a working (or at least, submitted) link and they
would be proximal in time: link 99 and link 100 were likely submitted very
close together in time, quite possibly by the same person.

A simple counter seems unacceptable here.

But what can a link shortener actually do to defend against enumeration? The
obvious answer is rate limiting. Nobody should be doing thousands of `GET`
requests against the shortener. And if the key space was made sparse so that
some of these `GET` requests result in a 404, that's also highly suspicious
and might make banning decisions a lot easier.

Therefore, I think **there should be rate limiting**, and **the key space
should be sparse** so that most guesses result in a 404 error.

When I say "sparse key space" I mean that the short link key that is generated
should be randomly and evenly distributed over a much larger range than is
required to fit all links in the database.

How sparse though? Should random guesses result in success 50% of the time?
1%? 0.1%? I don't know. I don't have a feel for how big a key space would be
to begin with. There is always the tension here against the primary purpose of
**being short**!

If that's not clear, consider a hash function like `md5`. You can feed
anything into `md5` and it'll give you back a 128 bit value which you could
use as the key (the short link). Even if you have billions of links in your
database, most of that 128 bit key space will be empty.

(If you're going to use a hash function for this, there's much better hash
functions than `md5`, but just to illustrate the point.)

The problem here is, well, it's 128 bits though. You might turn it into hex or
Base64 encode it but there's no escaping the fact that 128 bits of data is Not
Very Short and never will be.

Even if you do distribute over a decently large key space you'll want to cut
it down for brevity purposes, but it's hard (for me) to know how far you can
go with that. After all, if you have just 32 links in your database then you
could spread them out between /00 and /ff using only hex and less than 1 in 8
would correspond to a working link, right?

I don't know if 1 in 8 is a small enough hit rate, especially at the start
when it's clear to an attacker that your space has just 256 possible values.

### Alphabets

Moving on from the space in which the keys exist, what should they actually
_look_ like?

Since I don't yet know how big the key space will be, but do think it will
have to start big and be cut down, maybe I will start by just looking at
various ways of representing the full hash to see what kind of compression can
be achieved.

I've kind of settled on the idea of database keys being
[UUIDv7](https://buildkite.com/blog/goodbye-integers-hello-uuids). A UUIDv7 is
128 bits although 6 bits of it is reserved for version fields. Out of the top
64 bits, 60 of them are used for a timestamp. Of the bottom 64 bits, 62 of
them are used for essentially random data.

I'm thinking that these database keys will be private so it doesn't matter
that if you had one you could extract the submit time out of it (the top 60
bits). The purpose of having the first half of the key be time-based is to
make them a bit easier on the database, providing some locality. 128 bits of
key is massive overkill but I think it's worth it for the support (for UUIDv7)
across multiple languages and applications.

As I say, I know I'm not going to use all of the 128 bits of the UUIDv7 to
generate a short key but just to see what different representations would look
like I will start with the whole thing.

#### Base64

The typical answer to this sort of thing is
[Base64](https://en.wikipedia.org/wiki/Base64). A Base64 representation of 128
bits looks like this:

```txt
$ dd if=/dev/urandom bs=16 count=1 status=none | base64
uLU3DiqA74492Ma6IMXfyA==

```

The `==` at the end are padding and if this doesn't need to be decoded, i.e.
it's just being used as an identifier — as is the case here — then they can be
omitted. So that's a 22-character string.

#### Base64URL

Base64 has a few issues when used as parts of URLs. Its alphabet contains '+',
'/' and (when padding is included) '=', all of which are difficult when
included in a URL string.

[Base64URL](https://base64.guru/standards/base64url) is a modified Base64
alphabet that uses '-' and '\_' instead and has no padding. Apart from being
friendly for URLs it will also be 22 characters.

#### Base58

There are additional problems with Base64 besides its URL-unfriendly alphabet.
Some of it is also unfriendly to human eyesight. Its alphabet contains '1',
'l', 'O' and '0' which are easy to confuse with each other.

The Bitcoin developers came up with
[Base58](https://datatracker.ietf.org/doc/html/draft-msporny-base58) (but
let's not hold that against it…) in order to avoid these transcription
problems. Although short links will primarily be copied, pasted and clicked on
it does seem desirable to also be able to easily manually transcribe them. How
much would we pay for that, in terms of key length?

A Base58 of 128 bits looks like this:

```txt
CAfx7fLJ3YBDDvuwwEEPH

```

That happens to be 21 characters which implies it is somehow shorter than
Base64 despite the fact that Base58 has a smaller alphabet than Base64. How is
it possible?

It's because each character of Base58 encodes a fractional amount of data — 58
isn't a power of 2 — so depending upon what data you put in sometimes it will
need 22 characters and other times it only needs 21.

It can be quantified like this:

- Base64 = log2 64 = 6 bits encoded per character.
- Base58 = log2 58 = 5.857980995127572 bits per character.

It seems worth it to me. It's very close.

### How much to throw away

In order to help answer that question I wanted to visualise just how big
various key spaces would be. Finally, I could no longer avoid writing some
code!

I'd just watched
[Jeremy Chone's video about UUIDs and Rust](https://www.youtube.com/watch?v=zIebRwU0FOw),
so [I knocked together this thing](https://github.com/grifferz/explore-uuidv7)
that explores UUIDv7 and Base58 representations of (bits of) it. This is the
first Rust I have ever written so there's no doubt lots of issues with it.

The output looks like this:

```txt
Full UUID:
  uuid v7 (36): 018f244b-942b-7007-927b-ace4fadf4a88
Base64URL (22): AY8kS5QrcAeSe6zk-t9KiA
   Base58 (21): CAfx7fLJ3YBDDvuwwEEPH

Base58 of bottom 64 bits:
              Hex bytes: [92, 7b, ac, e4, fa, df, 4a, 88]

Base58 encodes log2(58) = 5.857980995127572 bits per character

IDs from…   Max chars Base58          Can store
…bottom 64b 11        RW53EVp5FnF =   18,446,744,073,709,551,616 keys
…bottom 56b 10        5gqCeG4Uij  =       72,057,594,037,927,936 keys
…bottom 48b  9        2V6bFSkrT   =          281,474,976,710,656 keys
…bottom 40b  7        SqN8A3h     =            1,099,511,627,776 keys
…bottom 32b  6        7QvuWo      =                4,294,967,296 keys
…bottom 24b  5        2J14b       =                   16,777,216 keys
…bottom 16b  3        6fy         =                       65,536 keys

```

The idea here is that the bottom (right most) 64 bits of the UUIDv7 are used
to make a short key, but only as many bytes of it as we decide we need.

So for example, if we decide we only need two bytes (16 bits) of random data
then there'll be 2¹⁶ = 65,536 possible keys which will encode into three
characters of Base58 — all short links will be 3 characters for a while.

When using only a few bytes of the UUID there will of course be collisions.
These will be rare so I don't think it will be an issue to just generate
another UUID. As the number of existing keys grows, more bytes can be used.

Using more bytes will also enforce how sparse the key space is.

For example, let's say we decide that only 1 in 1,000 random guesses should
hit upon an existing entry. The first 65 links can be just three characters in
length. After that the key space has to increase to 4 characters. That gets us
4 × 5.857980995127572 = 23 and change bits of entropy, which is 2²³ =
8,388,608 keys. Once we get to 8,388 links in the database we have to go to 5
characters which sees us through to 16,777 total keys.

## Wrap Up

Is that good enough? I don't know. What do you think?

Ultimately you will not stop determined enumerators. They will use public
clouds to request from a large set of sources and they won't go sequentially.

People should not put links to sensitive-but-publicly-requestable data in link
shorteners. People should not put sensitive data anywhere that can be accessed
without authentication. Some people will sometimes put sensitive data in
places where it can be accessed. I think it's still worth trying to protect
them.

## Aside

Having some [customers](https://bitfolk.com) who run personal link shorteners
that they keep open to the public (i.e. anyone can submit a link), I can tell
you they constantly get used for linking to malicious content. People link to
phishing pages and malware and then put the shortlink into their spam emails
so that URL-based antispam is confused. It is a constant source of
administrative burden.

If I ever get a minimum viable product it will not allow public link
submission.
