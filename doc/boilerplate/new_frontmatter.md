+++
title = "Title of the article"
# No date needed because filename or containing directory should be of the
# form YYYY-MM-DD-slug and Zola can work it out from that.
description = """
Brief description of post. Doesn't end with a period
"""

[taxonomies]
# see `docs/tags_in_use.md` for a list of all tags currently in use.
tags = [
    "list",
    "of",
    "tags",
]

[extra]
+++

Brief description paragraph, perhaps the same as the description in the
frontmatter but ending with proper punctuation.

{{ toc() }}
