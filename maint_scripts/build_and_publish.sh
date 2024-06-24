#!/bin/bash

set -eu

cd ~/src/ongoing-struggle

# Check if things we override in the tabi theme have been updated at all.
for f in templates/page.html; do
    if [[ "themes/tabi/$f" -nt "$f" ]]; then
        echo "$f in theme has been updated!"
        exit 1
    fi
done

zola build && \
    rsync -e 'ssh -q' -SHav --delete --exclude w/ \
    /home/andy/src/ongoing-struggle/public/ \
    use.bitfolk.com:/data/www-ssl/strugglers.net/
