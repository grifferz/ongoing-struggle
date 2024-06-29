#!/bin/bash

set -eu

warn_if_outdated() {
    local mine="$1"
    local theirs="$2"

    local my_ct
    local their_ct

    my_ct=$(git log -1 --pretty="format:%ct" "$mine")
    their_ct=$(git -C themes/tabi log -1 --pretty="format:%ct" "$theirs")

    if (( their_ct > my_ct )); then
        echo "$theirs in theme is newer than our $mine!"
        ((outdated++))
    fi
}

cd ~/src/ongoing-struggle

# Check if things we override in the tabi theme have been updated at all.
outdated=0

# Direct file matches (path to theirs is the same as the path to ours).
# This shellchec ignore while there's only one item in the list.
# shellcheck disable=SC2043
for f in templates/page.html; do
    warn_if_outdated "$f" "$f"
done

warn_if_outdated "templates/shortcodes/admonition_body.html" "templates/shortcodes/admonition.html"

if [ "$outdated" -ne 0 ]; then
    echo "$outdated file(s) found!" >&2
    exit 1
fi

zola check || {
    read -p "\`zola check\` failed. build and publish anyway? (y/N) " -n 1 -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting."
        exit 1
    fi
}

zola build &&
    rsync -e 'ssh -q' -SHav --delete --exclude w/ \
        /home/andy/src/ongoing-struggle/public/ \
        use.bitfolk.com:/data/www-ssl/strugglers.net/
