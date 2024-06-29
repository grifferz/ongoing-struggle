+++
title = "Thoughts on commenting facilities for this site"
description = """
This site, being a static one, presents some challenges with regard to
accepting comments from its readers. There's also a bunch of comments that
already exist on the legacy site. I have some thoughts about what I should do
about this
"""

[taxonomies]
tags = [
    "meta",
]

[extra]
+++

This site, being a static one, presents some challenges with regard to
accepting comments from its readers. There's also a bunch of comments that
already exist on the legacy site. I have some thoughts about what I should do
about this.

{{ toc() }}

## <abbr title="Too Long; Didn't Read">TL;DR</abbr>

I think I will:

- [x] Try to set up Isso at least for the purpose of importing old comments.
- [ ] Then I'll see what Isso is like generally.
- [x] ~If Isso didn't work for importing then I'll try the XML conversion
      myself.~
- [ ] Independently, I'll investigate the Fediverse conversation thing.

## Updates

### 2024-06-24

Isso was implemented and comments from the old Wordpress blog were imported
into it. I'm still unsure if I will continue to allow new comments through it
though.

## The problem

It's a bit tricky to accept comments onto a web site that is running off of
static files. JavaScript is basically the only way to do it, for which there
are a number of options.

There's a couple of hundred comments on the 300 or so articles that exist on
the legacy Wordpress site as well, and at least some of them I think are worth
moving over when I get around to moving over an article from there.

## Is it really worth having comments?

I mean, the benefits are slim, but they definitely do exist. I've had a few
really useful and interesting comments over the years and it would be a shame
to do away with that feature even if it does make life a lot easier.

So, conclusions:

- I should find a way to bring over some if not all of the comments that
  already exist.
- I should provide at least one way[^1] to let people comment on new articles.

Other people's value judgements can and will differ. A lot of this is just
going to be, like, my opinion, man.

## In that case, what to do about…

### Existing comments

I've got an XML export of the legacy blog which includes all the comment data
along with the post data.
[The Wordpress-to-Markdown conversion program that I've used](https://github.com/lonekorean/wordpress-export-to-markdown)
only converts the post body, though, so at the moment none of the articles
I've migrated have had their comments brought along with them.

I think it will be enough to also add the existing comment data as static
HTML. I don't think there's any real need to make it possible for people to
interact with past comments. There's some personal information that commenters
may have provided, like what they want to be known as and their web site if
any. There has to be a means for that to be deleted upon request, but I think
it will be okay to expect such requests to come in by email.

After a casual search I haven't managed to find existing software that will
convert the comments in a Wordpress XML export into Markdown or static HTML. I
might have missed something though because the search results are filled with
a plethora of Wordpress plugins for static site export. One of those might
actually be suitable. If you happen to know of something that may be suitable
please let me know! I guess that would have to be by email or Fediverse right
now (links at the bottom of the page).

It is claimed, however, that Isso (see [below](#isso)) can
[import comments from a Wordpress XML export](https://isso-comments.de/docs/guides/quickstart/#id2)!

#### The comments XML

Comments in the XML export look like this (omitting some uninteresting
fields):

```xml
<item>
  <wp:post_id>16</wp:post_id>
  <!-- more stuff about the article in here -->
  <wp:comment>
    <wp:comment_id>119645</wp:comment_id>
    <wp:comment_parent>0</wp:comment_parent>
    <wp:comment_author><![CDATA[Greyhound lover]]></wp:comment_author>
    <wp:comment_date><![CDATA[2009-07-08 10:35:14]]></wp:comment_date>
    <wp:comment_content><![CDATA[What a nicely reasoned and well informed article.

The message about Greyhound rescue is getting through, but far too slowly.

I hope your post gets a lot of traffic.

Ray]]></wp:comment_content>
  </wp:comment>
</item>
```

If I can't find existing software to do it, I think my skills do stretch to
using XSLT or something to transform the list of `<wp:comment></wp:comment>`s
into Markdown or HTML for simple inclusion.

Wordpress does comment threading by having the `<wp:comment_parent>` be
non-zero. I think that would be nice to replicate but if my skills end up not
being up to it then it will be okay to just have a flat chronological list.
I'll keep the data to leave the door open to improving it in future.

I haven't decided yet if it will be more important to bring over old comments,
or to figure out a solution for new comments.

### Future comments

All of the options for adding comments to a static site involve JavaScript.
Whatever I choose to do, people who want to keep JS disabled are not going to
be able to add comments and will just have to make do with email.

I'm aware of a few different options in this space.

#### Disqus

Just no. Surveillance capitalism.

#### giscus

[giscus](https://giscus.app/) stores comments in GitHub discussions. It's got
a nice user interface since the UI of GitHub itself is pretty fancy, but does
mean that every commenter will require a GitHub account and anonymous comments
aren't possible.

There's also [utterances](https://utteranc.es/) which stores things in GitHub
issues, but has fewer features than giscuss and the same major downsides.

I am Not A Fan of requiring people to use GitHub.

#### Hyvor Talk

[Hyvor Talk](https://talk.hyvor.com/) is a closed source paid service that's a
bit fancier than giscus.

I'm still not particularly a fan of making people log in to some third party
service.

#### Isso

[Isso](https://isso-comments.de/) is a self-hosted open source service that's
got quite a nice user interface, permits things like Markdown in comments, and
optionally allows anonymous comments so that commenters don't need to maintain
an account if they don't want to.

I think this one is a real contender!

#### Mastodon API

This isn't quite a commenting system, since it doesn't involve directly
posting comments.

The idea is that each article has an associated `toot ID` which is the
identifier for a post on a Mastodon server. The Mastodon API is then used to
display all Fediverse replies to that post. So:

1. You post on your Mastodon server about the article.
2. You take the `toot ID` of that post and set it in a variable in the
   article's
   [front matter](https://www.getzola.org/documentation/content/page/#front-matter).
3. JavaScript on your site is then able to display all the comments on that
   Fediverse post.

{% admonition_body(type="note", icon="info") %}

In this section I talk about "Fediverse" and "Mastodon".

I'm not an expert on this but my understanding is that _Fediverse_ instances
exchange data using
[the ActivityPub protocol](https://en.wikipedia.org/wiki/ActivityPub), and
_Mastodon_ is [a particular implementation](https://joinmastodon.org/) of a
Fediverse instance.

However, [Mastodon's API](https://docs.joinmastodon.org/api/) is unique to
itself (and derivative software), so this commenting system would rely on the
article author having an account on a Mastodon server. Though, everyone else
replying on the Fediverse would not necessarily be using Mastodon on _their_
instances yet their replies would still show up.

{% end %}

The effect is that a Fediverse conversation about your article is placed on
your article. [This project](https://github.com/dpecos/mastodon-comments) is
an example of such a thing.

Of course, not everyone has a Fediverse account and not everyone wants one,
but at least anyone potentially _can_, without having to deal with some
central third party. And if no existing Fediverse instance suits them then
they can set up their own. It's a decentralised solution.

The extremely niche nature of the Fediverse is pretty stark:

{% admonition_body(type="info", title="Active users", icon="note") %}

##### Fediverse

[~1 million](https://fedidb.org/) as of June 2024.

##### GitHub

[~100 million](https://github.blog/2023-01-25-100-million-developers-and-counting/)
as of January 2023 (unclear how "active" is defined).

{% end %}

Fediverse comments are also basically just plain text and links. Unfortunately
no way to express yourself better with Markdown or other styling.

Nevertheless, I like it. I think I want to pursue this. Maybe in combination
with Isso, if that doesn't get too noisy.

---

[^1]: "Email" doesn't count!
