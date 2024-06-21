+++
title = "Link shortener, part 2"
# No date needed because filename or containing directory should be of the
# form YYYY-MM-DD-slug and Zola can work it out from that.
description = """
In the previous article I had some thoughts about link shorteners, and how I
might try to implement one as a means to learn some Rust. Since then I've made
some progress and pushed it to GitHub
"""

[taxonomies]
# see `docs/tags_in_use.md` for a list of all tags currently in use.
tags = [
    "hacking",
    "linux",
    "rustlang",
    "migrated-from-wordpress",
]

[extra]
# On the basis that this was already published and doesn't need to be fed out
# again…
hide_from_feed = true
+++

In
[the previous article](https://strugglers.net/posts/2024/musings-on-link-shorteners-uuidv7-base58/)
I had some thoughts about link shorteners, and how I might try to implement
one as a means to learn some Rust.

Since then I've made some progress and
[pushed it to GitHub](https://github.com/grifferz/curtailing). It will not be
a good example of Rust nor of a link shortener. Remember: it's only the second
piece of Rust I've ever written. At the moment it only implements a basic REST
API and stores things in an in-memory SQLite database. I'll probably work on
it some more in order to learn some more.

I've really enjoyed the process so far of learning the Rust so far though. I
mean, it may lead to a lot of yak shaving on changing my editor to something
that will pop up all the fancy completions that you see the developers on
YouTube have. But other than that it was surprisingly fast to learn how to do
things even if not yet in the best possible way.

Things I found/find particularly helpful:

- Jeremy Chone's
  [web course on Axum](https://www.youtube.com/watch?v=XZtlD_m59sM)
- Andy Balaam's
  [Rust 101 videos](https://video.infosec.exchange/c/andybalaam_lectures/videos)
- Matt Palmer's article
  [The Mediocre Programmer's Guide to Rust](https://www.hezmatt.org/~mpalmer/blog/2024/05/01/the-mediocre-programmers-guide-to-rust.html)
