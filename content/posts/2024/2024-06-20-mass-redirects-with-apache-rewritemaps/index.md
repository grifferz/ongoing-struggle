+++
title = "Mass redirects with Apache RewriteMaps"
description = """
Part of this blog migration demands a lot of Apache redirects, made a bit
easier by RewriteMap
"""

[taxonomies]
tags = [
    "apache",
    "linux",
    "meta",
]

[extra]
add_src_to_code_block = true
+++

I've taken the decision to not reuse the same URI structure as my old
Wordpress blog, but
[cool URIs don't change](https://www.w3.org/Provider/Style/URI), so I'm going
to have to redirect all those old links — or at least the ones I think are
marginally "cool".

{{ toc() }}

## Aside: Could I not have just kept the same URIs?

Well, yeah, it was _technically_ possible of course, and generally desirable,
but I've decided not to for a variety of reasons, some of which I might have
to go into on an as-yet-to-be-written "About" page or something.

### Markdown

The new software uses Markdown. Wordpress export and conversion to Markdown
has got me 95% of the way there. Surprisingly far actually — even tables have
come out mostly right — but still every article I move over needs a minor
rewrite. I can't do that all at once and I'd rather not spend years doing it
without deploying any of it.

### New thing must be used

I'd like to be writing new articles in the new site. A big part of why this is
happening is that due to vision problems I can't actually read my old blog's
light theme any more. If I'm going to take the time to fiddle with a theme I
would rather take the opportunity to change away from Wordpress as well.

## Parallel running

So that leaves me in a situation where two blogs are running concurrently. I
think that's okay. The old Wordpress has been going since 2006 so is probably
okay to do so for a while longer. I might try to find a way to archive it to a
static version of itself but the main thing is, any time I find the time to
move an article over I'm going to have it redirect from its old URI to the
article on this blog.

## Simple redirects

Doing a redirect in Apache is simple enough. Since all my old blog articles
start with `https://strugglers.net/~andy/blog/2…` (They're all laid out like
`YYYY/MM/DD/slug`) I could just have a heap of:

{% wide_container() %}

```txt
Redirect permanent /~andy/blog/2024/04/28/musings-on-link-shorteners-uuidv7-base58 https://strugglers.net/posts/2024/musings-on-link-shorteners-uuidv7-base58
```

{% end %}

…but that's rather verbose and clutters up my Apache config file.

## Enter the `RewriteMap`

It took me a bit of time to understand
[the documentation](https://httpd.apache.org/docs/2.4/rewrite/rewritemap.html),
but basically it's possible to put key:value pairs in a separate file and have
just one `RewwriteRule` act on that:

{% wide_container() %}

```txt
RewriteMap blogmap "txt:/etc/apache2/legacy-blog-map.txt"
RewriteCond %{REQUEST_URI}            ^/~andy/blog/(2.*)$
RewriteCond ${blogmap:%1|NOT_PRESENT} !NOT_PRESENT
RewriteRule .?                        https://strugglers.net/posts/${blogmap:%1} [R,L]
```

{% end %}

### How it works

1. The first `RewriteCond` only proceeds if the request URI is in the format
   of a legacy blog article. If so it captures that part of the URI starting
   with the date, so like `2024/04/28/slug` and saves it in the first back
   reference (`%1`).
2. The second `RewriteCond` only proceeds if there is an entry for that `%1`
   in the map. If there's no entry this lookup returns `NOT_PRESENT` which
   fails the condition.
3. Assuming both those conditions passed, the URI is rewritten to the new
   prefix plus the lookup from the map.

An example of that map file for one migrated article is:

{% wide_container() %}
{{ add_src_to_code_block(src="/etc/apache2/legacy-blog-map.txt") }}

```txt
2024/04/28/musings-on-link-shorteners-uuidv7-base58 2024/musings-on-link-shorteners-uuidv7-base58/
```

{% end %}

It's not amazing but it's slightly smaller and tidier. I suppose I could go a
bit further as the slug part (the bit after the `YYYY/MM/DD/`) is I think
unique without the date, so in theory I could lop off the date from the start
of the key also. One for another day.
