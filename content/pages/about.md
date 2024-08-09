+++
title = "About this site and its author"
descriotion = "About this site and its author"
template = "info-page.html"

[taxonomies]
tags = [
    "meta",
    "personal",
]

[extra]
+++

{{ inline_image(src="/img/profile-violet-round-450px.png" alt="Andy with Violet the greyhound") }}

{{ toc() }}

## The author

Hi, I'm Andy! I'm a millennial-end-of-the-Gen-X-cohort computer-toucher and my
pronouns are he/him. I've been professionally touching computers since about
1994, generally with job titles like "systems administrator", "systems
engineer", "devops", "SRE" and so on. Since 2009 though my full time job has
been running [BitFolk](https://bitfolk.com/), a VM hosting company.

Since 2020 I've also been a
[professional dog sitter](https://dogsitter.services/)! I specialise in
looking after my favourite type of dog –
[sighthounds](https://en.wikipedia.org/wiki/Sighthound). Almost all of my dog
sitting clients are [greyhounds](https://en.wikipedia.org/wiki/Greyhound).

On this site I tend to mostly write about technical topics, with the odd
personal post mixed in. Over on my Fediverse account things are skewed more
towards personal posts and stuff about greyhounds! 😀

Since 2004 I've lived in London, UK.

## The site

The `strugglers.net` domain is quite old —- it was registered in 1998. Back
then most people didn't even have Internet access at home, let alone their own
web sites and email accounts outside of what was provided by their employer or
educational establishment. This site started off being shared by several
people, as even the cost of registering the domain was quite high back then.

I've always been the most dedicated user of this domain but over time the
other users made their own arrangements or just used other social media for
their online presence, until there was just me left using it. Since about 2006
I maintained a blog at [`/~andy/blog/`](https://strugglers.net/~andy/blog/)
but by June 2024 I decided it needed a major refresh. I also decided at the
same time to stop pretending that there are actually any other users here. So,
I took over the root of the domain.

### Software

Starting in 2006 Wordpress was used. The June 2024 migration was to a static
site generator called Zola. The old Wordpress site is now archived and
articles from it are being moved over, their old URIs redirected.

The site is served from a BitFolk VM running [Debian](https://debian.org/)
Linux.

### The mothballed blog

Aside from changing all the URIs I also decided not to just copy over all the
articles wholesale and hope they still worked. Conversion from Wordpress to
Markdown got about 95% of the way but aside from a lot of it being hopelessly
out of date, tables and photos need a bit of work. I decided to keep [a
mothballed archive of the old site][mothballed] and also migrate old posts
over one by one (redirecting URIs as I go).

So, if you still want to look at my older posts:

- Following a URI to one of them e.g. from a search engine will either get you
  the migrated version if I have got around to that or the mothballed version
  if I haven't.
- You can just browse them all at [the mothballed site][mothballed].

[mothballed]: https://strugglers.net/~andy/mothballed-blog/

There is a bit of an issue with [the site's feed][feed] as far as old posts
go. I redirected the old feed URI to the new one as I didn't want to lose any
subscribers, but I also excluded all migrated posts from being published in
the new feed as I didn't want old (potentially from 2006) content being shown
as new/unread.

The problem with that is that people who are new to this blog and actually
using feed readers (like all right-thinking persons should) will never see the
older posts.

I must admit I was a little surprised that anyone wanted to actually browse
those older posts if they hadn't already found them from a direct search, but
in August 2024 someone did actually contact me and ask for a way to find them!

My less than satisfactory answers at this time are:

- Look on the web at the [`migreated-from-wordpress`][migrated] tag to see all
  the posts I've got around to migrating.
- Additionally subscribe to [the feed of migrated posts][migrated-feed] which
  will have posts appear as new whenever I get around to migrating them.
- Look at [the mothballed site][mothballed].

I'm sorry that I haven't got better answers yet; let me know if this is too
annoying for you and the knowledge that there are actually people who are
bothered by this might spur me into doing something more about it.

[feed]: https://strugglers.net/atom.xml
[migrated]: https://strugglers.net/tags/migrated-from-wordpress/
[migrated-feed]: https://strugglers.net/tags/migrated-from-wordpress/atom.xml
