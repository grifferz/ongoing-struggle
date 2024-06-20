#!/bin/bash

set -eu

cd ~/src/ongoing-struggle

zola build && \
    rsync -e 'ssh -q' -SHav --delete --exclude w/ \
    /home/andy/src/ongoing-struggle/public/ \
    use.bitfolk.com:/data/www-ssl/strugglers.net/
