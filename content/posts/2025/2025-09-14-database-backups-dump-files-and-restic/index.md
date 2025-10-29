+++
title = "Database backups, dump files and restic"
# No date needed because filename or containing directory should be of the
# form YYYY-MM-DD-slug and Zola can work it out from that.
description = """
Some notes on converting my database backups away from intermediary dump files
"""

[taxonomies]
# see `docs/tags_in_use.md` for a list of all tags currently in use.
tags = [
    "backups",
    "restic",
]

[extra]
toc_levels = 2
+++

In the [previous article about rethinking my backups] I had a [TODO] item
regarding moving away from using intermediary dumps of database content.
Here's some notes about that.

[previous article about rethinking my backups]:
  @/posts/2025/2025-09-07-rethinking-my-backups/index.md
[TODO]: @/posts/2025/2025-09-07-rethinking-my-backups/index.md#todo

{{ toc() }}

## The old way

What I used to do in order to back up some `MariaDB` databases for example was
to have a script something like this called regularly:

```bash,name=mysqldump.bash
#/usr/bin/env bash

set -euf
set -o pipefail

umask 0066

# !!! Insecure file overwrite problem here if attacker can create their own
# /srv/backup/mariadb/all.sql.gz.new file. Should use secure temp file instead.
/usr/bin/mysqldump \
    --defaults-extra-file=/etc/mysql/backup_credentials.cnf \
    --single-transaction \
    --databases mysql dss_wp dev_dss_wp \
    | /bin/gzip --best --rsyncable -c \
    > /srv/backup/mariadb/all.sql.gz.new \
    && mv /srv/backup/mariadb/all.sql.gz.new /srv/backup/mariadb/all.sql.gz
```

So, every day the databases get dumped out to `/srv/backup/mariadb/all.sql.gz`
and then at some point that day the backup system picks that file up.

## Not ideal

That worked but has a few downsides.

### Redundant data storage

The data that's in the database also ends up on disk again, although in a
quite well compressed form.

### Constant change

Even if nothing in the database has changed, the dump file will always change.

`gzip` and many other compression tools are (or can be set to be)
deterministic, in that they will always produce the same output for a given
input, so it wasn't necessarily that. More that the metadata of the file such
as the inode and modification time would change, and that would be enough for
`rsnapshot` to store an entire extra copy.

There's various things that could be done to mitigate this but I never felt
like there was much point in spending time making the "no changes at all" case
highly efficient because there usually _was_ some change in the data, even if
it was small.

One of the mitigations I used was to switch to `btrfs` for the backup
repository and use reflinks. The `--rsyncable` flag to `gzip` then did help a
little. The `gzip` manual explains:

> Cater better to the rsync program by periodically resetting the internal
> structure of the compressed data stream. This lets the rsync program take
> advantage of similarities in the uncompressed input when synchronizing two
> files compressed with this flag. The cost: the compressed output is usually
> about one percent larger.

I figured that if it helped for `rsync` then use of that flag should help in
minimising changes in the compressed file generally. More on that later.

## The new way

Since I switched to using `restic`, I noted the recommendation to use its
[standard input backup mode] for things like this. This would address the
above shortcomings as:

1. It doesn't store anything extra on the database host, and;
2. it deduplicates, compresses and encrypts the data itself anyway.

[standard input backup mode]:
  https://restic.readthedocs.io/en/stable/040_backup.html#reading-data-from-a-command

The replacement `mysqldump` script now looks a bit like:

```bash,name=mysqldump_restic
#!/usr/bin/env bash

do_dump() {
    local dbnames=("$@")
    # Prepend "db_" to each element of dbnames.
    local extra_tags=( "${dbnames[@]/#/db_}" )
    # Comma separate.
    local extra_tags_string=$(IFS=,; printf "%s" "${extra_tags[*]}")

    local ignored_tables=(rt5.sessions)

    printf "Starting mysqldump / backup for DBs: %s…\n" "${dbnames[*]}"
    printf "  Ignoring tables: %s\n" "${ignored_tables[*]}"

    # "--stdin-filename" must not contain "/" due to restic bug
    # https://github.com/restic/restic/issues/5324
    /usr/local/sbin/restic \
        --retry-lock 1h \
        backup \
        --no-scan \
        --group-by host,tags \
        --tag "db,db_mariadb,${extra_tags_string}" \
        --stdin-filename "mariadb.sql" \
        --stdin-from-command -- \
        /usr/bin/mysqldump \
        --defaults-extra-file=/etc/mysql/backup_credentials.cnf \
        --default-character-set=utf8mb4 \
        --skip-dump-date \
        --databases "${dbnames[@]}" \
        --ignore-table "${ignored_tables[@]}" \
        --single-transaction

    printf "Finished mysqldump / backup for DBs: %s\n" "${dbnames[*]}"
}

do_dump rt5
```

## Learnings

I have now converted all of my database backup scripts to this way of doing
things and discovered a few things along the way.

### Avoid pipe confusion with `--stdin-from-command`

Not much of a "discovery" since it's right there in the documentation, but I
did do a web search for other people's scripts for database backups using
`restic` and oh boy let me tell you, _many_ of them are still doing the
equivalent of:

```txt
mysqldump … | restic backup --stdin
```

That will work most of the time, but does have some caveats regarding the exit
code of piped commands. If not careful you can end up making empty backups of
a failed `mysqldump` and not noticing.

You can try using `set -o pipefail` and/or you can use `bash`'s `PIPESTATUS`
array to examine the exit code of any part of a pipeline. But really, it is
much easier to sidestep the issue by not using a pipe at all:

```txt
restic backup … --stdin-from-command -- mysqldump …
```

In that form `restic` will fail if the command it's executing fails.

### Specifying the filename

Naturally, `stdin` doesn't have a filename. You can get around this with the
`-stdin-filename` flag. If you use `--stdin-filename foo` then whatever your
command outputs will appear as the file `/foo` inside the backup snapsshot.

{% admonition_body(type="note") %}

There's a [bug] in the currently-released version of `restic` where it doesn't
allow the `/` character anywhere in the filename, so you can't fake the
existence of subdirectories. It doesn't really matter since there's only one
file and if you _did_ restore it to the filesystem it would be in a relative
path anyway.

The bug has been fixed but the fix isn't in a release yet at the time I write
this.

[bug]: https://github.com/restic/restic/issues/5324

{% end %}

### Use tags to differentiate and group backups

It's a good idea to tag these backups in some way.

With `restic`, backups are by default grouped by host and the set of paths
that were specified to backup. I found however that a backup using
`--stdin-from-command` has an empty set of paths for grouping purposes even
though `--stdin-filename` is used. I don't know if this is a bug.

The consequence here is that if you have multiple of these types of backups
for a single host, by default `restic` will use the most recent one as the
parent for the current one _even if it has a different command and/or
`--stdin-filename`_. This doesn't cause too many problems, it's just a bit
confusing and will result in a later `diff` command showing one database dump
file being removed and the other added, every time.

It can easily be avoided though by setting `--group-by` to include `tags` and
making sure different database backups are tagged differently. It is probably
a good idea to use some tags anyway so you can programmatically identify what
the backups are. This will be useful later if for example you want to have
different retention periods for different kinds of data, or for different
databases.

I tag my general host backups as `auto`, and all the database backups as `db`.
Then, there is `db_mariadb`, `db_postgresql` and `db_sqlite` for backups that
have come from `MariaDB`, `PostgreSQL` and `SQLite` respectively. Finally I am
also adding a tag for each named database.

I think I probably will want to retain most databases for the same time period
as general host backups, but I know there are a few less important databases
that I will retain for a shorter time. Having those tagged will be helpful for
writing the
[`forget` policy](https://restic.readthedocs.io/en/stable/060_forget.html#removing-snapshots-according-to-a-policy)
later.

### I learned about `mysqldump --skip-dump-date`

Using `--skip-dump-date` removes some timestamps from comments which helps to
reduce churn.

### It really is storing less churn

Having had this running for a few days now I can see it really is storing less
of a delta. In the case where I do have databases that haven't changed at all,
the snapshot ends up just being a couple of hundred bytes which I assume is
just metadata.

You can tell `restic` not to store a backup with no changes at all, but I like
doing so as a record of a successful but unchanged backup.

### That `--rsyncable` really does work

My old `mysqldump` scripts all used `gzip --rsyncable` but at some point it
seems I decided that better compression was more important, so some of them
ended up using `xz`.

I never really examined in detail what the churn was like because `rsnapshot`
made that quite awkward to do, especially after I switched it to using
reflinks. I have been able to look at it now though, because I've been doing
`restic` backups for some time before adjusting those `mysqldump` scripts.

What I can tell you is that `restic` _is_ able to effectively deduplicate a
database backup file made with `gzip --rsyncable` whereas the ones that are
compressed with `xz` show huge amounts of daily churn even when the database
had little.

My conclusions:

- `gzip --rsyncable` really _does_ work for minimising changes if the source
  file doesn't change much.
- `zstd` now has a similar `--rsyncable` flag.
- `xz` was a bad choice
- If you don't want to do all this `--stdin-from-command` malarkey or can't
  because you're doing backups another way, `--rsyncable` is well worth using.
  It's nearly as good as just letting `restic` deduplicate the raw SQL.
