+++
title = "Rethinking my backups"
# No date needed because filename or containing directory should be of the
# form YYYY-MM-DD-slug and Zola can work it out from that.
description = """
Rethinking how I do my backups
"""

[taxonomies]
# see `docs/tags_in_use.md` for a list of all tags currently in use.
tags = [
    "backups",
    "btrfs",
    "restic",
    "rustic",
    "rustlang",
]

[extra]
toc_levels = 1
+++

Growing difficulties with `rsnapshot` spurred me in to a long-overdue rethink
of how I do my backups. I decided to evaluate `restic` and `rustic` for this
purpose and here's some notes on that.

{{ toc() }}

## A brief introduction on how `rsnapshot` works

For about two decades I have done all my backups with the venerable
[rsnapshot].

[rsnapshot]: https://rsnapshot.org/

`rsnapshot`'s deal is:

1. You'd usually run it on a central server.
2. It connects out to the thing you want backed up using `rsync` over `ssh`
   and brings back all the data into a sequence of snapshot directories, for
   example `daily.0`, `daily.1`, … `daily.6`, `weekly.0`, … `weekly.3`,
   `monthly.0`, … `monthly.56`.

The names of these snapshots are arbitrary; the actual age of them simply
depends upon when you called `rsnapshot` and how many of them you told it to
keep.

For example if you used the configuration:

```txt,name=/etc/rsnapshot.conf
interval	daily   7
```

…then every time you ran a backup it would do:

```txt,name=terminal
rm -r daily.6
mv daily.5 daily.6
mv daily.4 daily.5
mv daily.3 daily.4
mv daily.2 daily.3
mv daily.1 daily.2
mv daily.0 daily.1
cp -al daily.1 daily.0
```

By this means the oldest daily backup is destroyed, each earlier one gets
shifted back one day, and then the most recent one gets copied with hard links
as the basis for the new snapshot. Since hard links are used here, `daily.0`
and `daily.1` are at this point identical but the data doesn't take up any
extra space (space is still needed for the inodes that contain the filesystem
metadata so this doesn't break the laws of physics to make it _entirely_
free).

In reality you would likely have more intervals like:

```txt,name=/etc/rsnapshot.conf
interval	daily   7
interval	weekly	4
interval	monthly	72
```

This would tell it to also move `daily.6` to `weekly.0`, `weekly.3` to
`monthly.0` and so on.

The clever thing here is that the `rsync` that `rsnapshot` calls is only going
to mess with the file in the `daily.0` directory if the current file on the
target differs from it in some way that `rsync` is able to determine. If
`rsync` sees no change then the file remains a hardlink to it its previous
version and takes up almost no space.

In a real `rsnapshot` setup there's a subdirectory in each interval for the
particular thing (e.g. a host) that is being backed up. So, the directory tree
will end up looking like:

```txt,name=terminal
$ tree /srv/rsnapshot
├── daily.0
│   ├── foo.example.com
│   │   ├── home
│   │   │   ├── andy
│   │   │   │   ├── .bash_profile
│   │   │   │   │
.   .   .   .   .
│   ├── bar.example.com
│   │   ├── home
│   │   │   ├── andy
│   │   │   │   ├── .bash_profile
│   │   │   │   │
.   .   .   .   .
├── daily.1
│   ├── foo.example.com
│   │   ├── home
│   │   │   ├── andy
│   │   │   │   ├── .bash_profile
│   │   │   │   │
.   .   .   .   .
│   ├── bar.example.com
│   │   ├── home
│   │   │   ├── andy
│   │   │   │   ├── .bash_profile
│   │   │   │   │
.   .   .   .   .
```

### Advantages of `rsnapshot`

#### Simple deployment

You don't get a lot more simple than `rsync` over `ssh` and a `perl` script
with no non-core dependencies, that you only have to have in one place. All
the backup targets require is working `ssh` and an `rsync` binary.

#### Simple restores

All the files are just there on disk in a regular filesystem.

### Limitations of `rsnapshot`

#### Quickly becomes unwieldy

Unless you're only backing up a fairly trivial amount of data, one inode per
file per interval quickly becomes an unwieldy filesystem tree to work with.
Operations on a tree of hundreds of millions of files are not cheap, even if
most of them are just hardlinks.

This is actually the worst limitation that `rsnapshot` has, though it's a
pretty short explanation. At every backup the `rsync` component has to
traverse the entire tree of that host's previous backup and for each file
decide whether it will do nothing (file hasn't changed, so hard link can stay
where it is) or if it must transfer the file (file changed so hard link must
be broken and new content stored). For any appreciable number of files this
will cause the scan time of the backup to be far in excess of the time spent
actually transferring data.

But so what? As long as you only want to do a backup say once a day, you have
all day to do it, right?

That's true, but that's not where the most pain exists. The most pain exists
when trying to manage the backups — when trying to do the basic admin tasks
that are inevitable in a working system. Things like trying to work out…

- how much data changed between two different backup runs for a given host
- _which_ files exactly changed between two different backup runs

…and things of that nature.

{% admonition_body(type="info", title="Detecting change with hard links") %}

Thankfully checking if two exact file paths are identical is still pretty
cheap, thanks to hard links.

Under `rsnapshot`'s design, if two versions of a file path are identical then
they should be hard links to each other, and hard links all have the same
inode number. That is, if `daily.0/foo.example.com/home/andy/.bash_profile`
and `daily.1/foo.example.com/home/andy/.bash_profile` have the same inode
number then they are by definition the same file, which means there were no
detectable changes between the times that `rsnapshot` ran. There's no need to
look at the files' content; a `stat()` system call will do.

Of course, if they _aren't_ the same inode number then they're _probably_
different files and you would have to confirm that by looking at the file
content.

{% end %}

I want to be clear that this only becomes a problem when you have a really
large number of files that you are keeping for many `rsnapshot` intervals.

Exactly how many you can have before it becomes unwieldy will depend upon how
beefy your backup server is, mainly in the form of how many random I/O
operations per second its storage can do. If you're far off from that point
then `rsnapshot` is a really good system because it's so simple!

The rest of the limitations are ones I could have put up with, but let's talk
about them anyway.

#### Crude deduplication

When most people think about the term _deduplication_, they think of it in
terms of chunks of data. `rsnapshot` can only do deduplication in terms of
whole files.

Due to the use of hardlinks, entirely identical files do not consume any
additional space for their data, just an inode for the hardlink. The "entirely
identical" part of that sentence is concealing a multitude of caveats. **As
soon as anything about the file changes, `rsync` will send a new version of
the entire file**.

If just the ownership, permissions or any other metadata like modification
time change, you'll get an entirely new copy of both sets of file data.

If just one byte is added (_or removed!_) you'll get an entirely new copy of
all the file's data.

What's more, _the file paths have to remain the same too!_ If you have
`/srv/immense_tree_of_files` and rename it to
`/srv/why_did_i_store_this_immense_tree_of_files`, your backups will contain
the entire content of both file trees until the oldest backup ages out. It
doesn't matter that every file within that tree is still identical to the same
path within the other tree.

If you're backing up a big log file that gets a little bit appended and then
rotated, you'll get full a copy under the new name (e.g. `syslog.1`) and
multiple full copies under its current name.

As a consequence of all of the above it also follows that the same file path
and contents between backup targets will always be backed up multiple times,
because there is no deduplication between targets, i.e.
`daily.0/foo.example.com/home/andy/hugefile` and
`daily.0/bar.example.com/home/andy/hugefile` both get stored even if they are
actually the same file.

Even crude deduplication can get you a long way though. The seven `daily.*`
intervals plus the four `weekly.*` intervals of my current `rsnapshot`
repository reference 13.1 times as much data as actually appears on disk. That
is, if I'd simply stored a copy every day for the last seven days plus also a
copy once per week for four weeks prior to that, I would need more than 13
times as much storage to do it.

#### No compression

The file tree is just stored on disk in a regular filesystem. There's no
compression going on unless the filesystem offers it.

#### No encryption

The file tree is just stored on disk in a regular filesystem. There's no
encryption going on unless the filesystem offers it.

#### Not very portable

This wasn't a factor for me because all of my machines started off being Unix
and later ended up being only Linux, but I suppose some people might have
difficulty getting their backup targets to run an `sshd` and have a working
`rsync`.

## A short-term band-aid

Running up against all of those limitations I took some steps to prolong the
life of what I was doing.

Firstly I used LUKS to format the backup filesystem, so on disk it's encrypted
and hopefully anyone coming into possession of the backup server would have a
power cycle in between and so wasn't going to be able to get at it.

Secondly, I was running out of storage capacity so I put the backup filesystem
on `btrfs` with a mount option of `compress-force:zstd` so that it would
always try to compress everything. That reduced the total size on disk by
about 24%. Approximately 57% of my backed up data (by bytes) is not
compressible at all. The rest did compress down to around 45% of its original
size on average.

Thirdly, in an attempt to make deduplication slightly more effective, I
changed from using `rsync`'s hard links support to doing a
`cp -a --reflink=always` and made `rsync` do `--in-place`. That uses a
reflinked copy instead of a hardlink and then hopefully when the file is
changed, only the parts of it that actually did change will get new extents on
the filesystem.

This last change still did not address the problem of renamed paths since
`rsync` will write a whole new file if there's not one in place already.

I don't have the data to make a determination of how well this worked for
deduplication but my gut feeling is that it wasn't a huge amount. What also
happened is that it made it much harder to manage, so if I could wind back
time I would probably stop at encryption and compression.

## Breaking point

Recently the disk space I had available for storing the backups was exhausted
again and I found myself having a very hard time actually working out why. I
mean, obviously the high level _why_ is because I backed up too much stuff!
But answering questions like:

- which interval grew by the most?

- which host in an interval grew the most?

- which files changed between two specific pairs of interval/host (e.g.
  `daily.1/foo.example.com` vs `daily.0/foo.example.com`)?

…were extremely slow to compute given a tree of hardlinks. There are currently
over 400 million files in my `rsnapshot` tree.

My use of reflinking made it even more difficult. Before reflinks it was a
cheap operation to look at the inode numbers of two files. Remember: if
they're the same then by definition the files are the same file. With reflinks
in use each file is a collection of extents and there's no way to tell if
they're identical without listing out the extent ranges and seeing if they
match (and then if they _don't_ you probably have to compare the content
anyway, just to be sure).

Just walking through a few trees out of the filesystem was taking more than an
hour and that's before trying to actually _do_ anything with any of the files.

My gut feeling was also that there was more scope for deduplication, but I
could think of no practical way to do it. By this point my backup host had
four HDDs in a RAID-10 and 64GiB of RAM but trying to run something like
`duperemove` across the whole backup tree would take all day (during which
time no more backups could happen!) before running out of RAM and dying.

I gave [BEES] a go since this was by now a `btrfs` filesystem, but never got
it to work properly. I considered `zfs` with its native deduplication but I
found even 64GiB RAM wouldn't be enough. I could do without `zfs`'s
deduplication because the inherent deduplication of `zfs` snapshots would
probably be enough, but my tests showed I'd still need more expensive hardware
and my other off-site backups of this would have to be done differently as
well (much more expense).

[BEES]: https://github.com/Zygo/bees

In the end I eventually did determine that there wasn't actually anything
unexpected about my `rsnapshot` backups. They had simply outgrown the storage
I had available.

Fixing that would require a new backup server though and I started to wonder
to myself if just setting up the same `rsnapshot` on a new server was the best
that I could do. Could I face spending all the effort just to end up with a
thing that had more storage but still so many irritating limitations?

Having a look at the most recommended modern Unix backup systems, I decided to
evaluate [BorgBackup], [restic] and [rustic] as alternatives.

[BorgBackup]: https://www.borgbackup.org/
[restic]: https://restic.net/
[rustic]: https://rustic.cli.rs/

## First impressions of alternatives

### BorgBackup

`rsnapshot` is a pull-based backup system: the backup host connects out to
every machine to be backed up and pulls the data back to itself. Every other
system I was going to look at is _push_-based: The machine that is being
backed up runs something that connects out to the backup server to push its
data in to the backup repository.

Under `rsnapshot` each machine only had to run an `sshd` and have an `rsync`
binary, but with any of the alternatives I looked at each machine would have
to run the backup software itself.

Since `BorgBackup` is a Python application, this ruled it out for me straight
away. I do not generally enjoy deploying Python applications and the idea of
having to do it on pretty much every system I run was not appealing. I don't
care if it could possibly be done by any of the means of packing a Python app
into a single executable blob. I don't want to deal with it.

Moving on.

### restic

`restic` at first glance has all the attributes I was looking for:

- It's a Go application, so its single binary is completely static and will
  run anywhere. I embarrassingly do still have a couple of 32-bit (i686)
  hosts, so I'd just need two different `restic` binaries.
- It does encrypted, deduplicated backups.
- It supports many storage backends. I really only needed `sftp` but it also
  can talk to a thing called
  [`rest-server`](https://github.com/restic/rest-server) which is a separate
  application that exposes a `restic` repository over `HTTP(S)`. This performs
  better than `sftp`, offers more interesting authentication options, and some
  other useful properties like "append-only mode":
  > The `--append-only` mode allows creation of new backups but prevents
  > deletion and modification of existing backups. This can be useful when
  > backing up systems that have a potential of being hacked.

`restic` seems to have a fairly active set of developers and a reasonably
large [user community].

[user community]: https://forum.restic.net/

### rustic

`rustic` is a re-implementation of `restic` but in Rust. `restic` is
well-documented and is of course open source, so its repository format is
known. This has enabled a few different tools to work with `restic`
repositories, perhaps the most ambitious being `rustic` which aims to be a
complete but compatible alternative.

As far as deployment goes, Rust applications are almost as easy as Go ones as
they statically link everything except the C library. This does mean that a
few different compiles can be required depending on the version of glibc
present on the host. Alternatively, a completely static binary can be compiled
that uses [musl libc] instead of glibc, and that should work anywhere with the
same architecture. Deployment was not going to be an issue.

[musl libc]: https://www.musl-libc.org/

Initial experimentation suggested that `rustic` might have a slightly flashier
user interface (better progress bars, etc.), a few more convenient commands
and slightly lower memory usage. I decided to start with `restic` though,
owing to it being the more established project.

## Importing data from rsnapshot

It would have been quite easy to just cut over from using `rsnapshot` to using
the new thing, but I decided that it would be wise to import as much data as
possible so that I could get a good idea how how the new solution would scale
when it actually had an appreciable amount of data in it.

This was going to take quite a long time. The machine with the `rsnapshot`
data on it is at a remote data centre, and the new machine I was experimenting
with is at a different data centre of the same hosting company. While there
was only 1.6 TiB of data on disk, any new system was going to have to read it
all in its deduplicated raw state, which in this case was more than 14 TiB of
data to be processed.

### Pathname conundrum

The first stumbling block was `restic`'s handling of path names. If you
recall, I was starting with an `rsnapshot` repository with top level directory
trees like this:

```txt,name=terminal
$ tree -L 1 daily.0/foo.example.com/
daily.0/foo.example.com/
├── etc
├── home
├── opt
├── srv
└── var
```

The `daily.0` here is the interval of that backup that `rsnapshot` took. The
directory `foo.example.com` contains the backups for a host by that name, and
data for directories like `/etc/`, `/home/` and so on are within that. So,
given that I can tell `restic` both the host name and the time that the backup
it is about to do (as oposed to having it assume hostname and current time), I
could just script it being run against every host directory in every interval,
right? Right???

Well it turns out that `restic` always wants to fully-qualify path names, so
in the example above it would not be backing up `/etc/`, it would be backing
up `/srv/rsnapshot/daily.0/foo.example.com/etc/`! The time and host name would
be correctly faked, but those paths would not be the same as a later real
backup run on the real `foo.example.com`.

The consequences of this are not dire.

`restic` uses a content-addressed store, so these path mismatches don't affect
deduplication — data will be chunked and if that content is already in there
then it won't be sent or stored twice no matter where it is found again, it
will just be a small amount of metadata for the paths.

What it _will_ affect is historical context, i.e. the ability to tell that
`/srv/rsnapshot/daily.0/foo.example.com/etc/fstab` at time _t_ is the same
file as `/etc/fstab` at time _t+1_, where time _t_ was a backup taken with
`rsnapshot` and _t+1_ taken later with `restic`, is lost. A `diff` command
done between these two snapshots will just show all the paths as removed files
and then all the files put back again as new.

This could just be accepted: It would only matter for queries across that
single boundary in time. `restic`'s developers don't consider it a big deal
and don't seem to have any plans to do anything about it. Fair enough. It
bothered me though.

This is one area where `rustic` is a bit friendlier. It supports relative
paths! So, if you:

1. change in to an `rsnapshot` directory like `daily.0/foo.example.com`
2. tell it to back up `etc/`, `home/`, `opt/`, `srv/` and `var/` (relative
   paths)
3. go to the real `foo.example.com` host
4. change to `/`
5. again back up `etc/`, `home/`, `opt/`, `srv/` and `var/` (relative paths)

then it will

- correctly determine that the first backup can be "parent" of the current
  one, and
- store matching paths which can be properly `diff`ed afterwards!

{% admonition_body(type="info", title="Parent snapshots") %}

The idea of "parent" snapshots is just to speed up change detection. If
`restic` sees that it already did a backup for this host with this same set of
paths then it will consider the most recent snapshot to be the parent of the
new one. That just enables `restic` to compare its stored file metadata with
the file metadata on the host being backed up, so it can decide whether it has
changed and thus requires backing up again.

If `restic` can't identify a parent snapshot then it has to read all of the
file content before it can determine whether any of it needs sending and
storing.

{% end %}

Another nicety of `rustic` is that it can fake the time of a backup on the
command line, whereas `restic` can only do so after the backup has completed —
you basically issue a command to alter the metadata of the snapshot to say it
happened at a different time. This creates a new snapshot with the desired
time, leaving you to `forget` and `prune` the old one afterwards. That wasn't
a huge deal, it was just a bit more convenient.

I decided to build a script around `rustic` that would start importing the
`rsnapshot` backups.

{% admonition_body(type="note", title="restic vs rustic terminology") %}

Even though at this point I was using the `rustic` binary to import backups, I
will still generally call this system `restic` in this article because it's a
`restic` structured repository and the protocol is what `restic` says it is.
When I say `rustic` it will be in regard to the specific use of the `rustic`
binary.

{% end %}

### The import script

I wrote a script that would operate on an individual interval directory of the
`rsnapshot` tree, e.g. `daily.0` or `weekly.3` and so on. The script would:

1. Get the modification time of the parent directory and assume the backup
   happened at that time
2. Iterate through each subdirectory, using the subdirectory as the host name
   for that backup and the time from step 1 as the time of the backup

This was using `rustic` over HTTPS to a `rest-server` in append-only mode.
Importing the first interval got most of the unique data into the `restic`
repository and after that each interval took about 2 hours to process. This
time was quite predictable and I assume this was because `rustic`'s work was
dominated by processing through the data on disk, checking it against the
repository and mostly finding that there was nothing to send.

Additionally, backups in `restic` can have tags as part of their metadata. I
decided it would probably be helpful to tag all of these imports with
`from_rsnapshot` and a tag based on the `rsnapshot` interval, e.g.
`rsnapshot_daily_0`, `rsnapshot_weekly_2`, etc.

This was all going very well! I'd got all the `daily.*` intervals imported and
was pleased to note that the 568 GiB of `rsnapshot` data this comprised has
translated into 515 GiB in `restic`. The `btrfs` filesystem that the
`rsnapshot` data was in had `zstd:1` compression on it, and `restic` is using
`zstd` for compression too, so this was probably due to the better
deduplication.

### Some steps towards real backups

Since I had quite a lot of spare time waiting for all these scripted imports
to complete, I decided to work on my configuration management (Ansible) to set
up each host to push a backup into `restic` every day.

#### Ignoring things that shouldn't be backed up

A tedious part of this was converting from my old way of ignoring files and
directories into something that `rustic` supported.

My `rsnapshot` backups of course were using `rsync` which has its own filter
language. I had set that to look for files called `.bitfolk-rsync-filter` in
each directory. The rules in that file would only apply to entries _in that
directory_. I had files like this:

```txt,name=/var/.bitfolk-rsync-filter
- cache/
```

```txt,name=/home/andy/.bitfolk-rsync-filter
- .cache/
```

`rustic` has a `--glob-file` option where you specify a file that contains a
list of glob patterns to exclude (or include). Exclude lines to replicate the
above could be in just one file and would look like:

```txt,name=/etc/rustic/excludes
!/var/cache/
!/home/andy/.cache/
```

It's pretty clear how to convert from one to the other but I've got _many_
hosts and I hadn't been disciplined about deploying the
`.bitfolk-rsync-filter` files from config management. I ended up running this
bit of bash:

```bash
#!/usr/bin/env bash

for f in $(sudo find /data /etc /usr/local /var \
            -type f -name .bitfolk-rsync-filter); do
    echo "# $f"
    dn=$(dirname "$f")
    sudo grep -Ev '^(#|$)' "$f" | sed "s|^- |!$dn/|"
done
```

That finds all the `.bitfolk-rsync-filter` files on the system and produces
output like:

```txt
# /usr/share/.bitfolk-rsync-filter
!/usr/share/doc-base/
!/usr/share/doc/
!/usr/share/locale/
!/usr/share/zoneinfo/
# /etc/.bitfolk-rsync-filter
!/etc/logcheck/
# /var/.bitfolk-rsync-filter
!/var/cache/
!/var/lock/
!/var/log/
# /var/spool/.bitfolk-rsync-filter
!/var/spool/exim4/
!/var/spool/uptimed/
# /var/backups/.bitfolk-rsync-filter
!/var/backups/dpkg.status.*.gz
# /var/lib/.bitfolk-rsync-filter
!/var/lib/apt-xapian-index/
!/var/lib/apticron/
!/var/lib/arpwatch/
!/var/lib/greylistd/
!/var/lib/logcheck/
!/var/lib/logrotate/
!/var/lib/mysql/
!/var/lib/node_exporter/
!/var/lib/pengine/
!/var/lib/percentilemon/
!/var/lib/php5/
!/var/lib/schroot/
!/var/lib/smokeping/
!/var/lib/spamassassin/
!/var/lib/sudo/
```

…and so on.

I took the opportunity to check all of these ignores were still relevant, and
put them into config management. This took a really long time!

#### Spreading the jobs out a bit

The vast majority of the hosts being backed up are virtual machines on a
smaller number of bare metal servers. I didn't want them all to start running
a backup job all at the same time.

In a `systemd` timer unit you can do a `RandomizedDelaySec=` to spread
activations out randomly. I wanted there to be 24 hours between runs on any
given host though. Since Debian 12 (bookworm) you can _also_ specify
`FixedRandomDelay=true` and then the delay will be random per host but
deterministic on that host.

So, here's an example of a timer that triggers within 6 hours from 21:00:00:

```txt,name=/etc/systemd/system/rustic-backup.timer
[Unit]
Description=Do a daily backup starting at a random time \
    within 6 hours from 21:00

[Timer]
OnCalendar=*-*-* 21:00:00
RandomizedDelaySec=6h
FixedRandomDelay=true
Persistent=false
Unit=rustic-backup.service

[Install]
WantedBy=timers.target
```

## Repository corruption incident

At this point I had a scripted import running from the `rsnapshot` host and
had most of the production hosts ready to start doing daily backups overnight.
The next day I found that my new backup host had filled its filesystem, and
due to this my import script had bailed out and there were several
partially-completed overnight backups. I had obviously missed some things on
the production hosts that should have been excluded from being backed up.

I was able to get a list of all backups ("snapshots", in `restic` terminology)
that had completed so I tried to do a `diff` between the most recent snapshot
for a host and its corresponding one tagged `rsnapshot_daily_0` in order to
attempt to work out what I had accidentally backed up. This resulted in
`rustic` complaining about missing pack files and crashing!

I thought perhaps it was because the filesystem was full. I grew the
filesystem a bit. Same problem.

I thought perhaps it was because some of the last backups had only partially
completed and the repository might need the `check` command to be run,
possibly followed by some of the `repair` commands. I ran `check` and got:

```txt,name=terminal
$ sudo rustic check
[INFO] using config /etc/rustic/rustic.toml
[INFO] repository local:/srv/restic/repo: password is correct.
[INFO] using no cache
[00:00:00] getting snapshots...           ████████████████████████████████████████
[00:00:01] reading index...               ████████████████████████████████████████ 577/577
[00:00:00] listing packs...
[WARN] pack e04d6298 not referenced in index. Can be a parallel backup job. To repair: 'rustic repair index'.
[WARN] pack e0351889 not referenced in index. Can be a parallel backup job. To repair: 'rustic repair index'.
[WARN] pack 51cab1d1 not referenced in index. Can be a parallel backup job. To repair: 'rustic repair index'.
[WARN] pack 515975ce not referenced in index. Can be a parallel backup job. To repair: 'rustic repair index'.
[WARN] pack 51942075 not referenced in index. Can be a parallel backup job. To repair: 'rustic repair index'.

[…many more of this similar message…]

[00:00:00] listing packs...
[00:00:00] checking trees...              ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 0/904
[ERROR] dir "boot" subtree blob 64b7176d is missing in index
[ERROR] dir "data" subtree blob f614dc41 is missing in index
[ERROR] dir "etc" subtree blob 9ff42fd0 is missing in index
[ERROR] dir "home" subtree blob f4f1f48e is missing in index
error: `rustic_core` experienced an error related to `internal operations`.

Message:
Tree ID `64b7176d` not found in index


Some additional details ...

Backtrace:
disabled backtrace (set 'RUST_BACKTRACE="1"' environment variable to enable)
```

So, `repair index` then?

```txt,name=terminal
$ sudo rustic repair index
[INFO] using config /etc/rustic/rustic.toml
[INFO] repository local:/srv/restic/repo: password is correct.
[INFO] using no cache
[WARN] error reading pack 5e7121d3 (-> removing from index): Error: Data is too short (less than 16 bytes), cannot decrypt. (kind: related to cryptographic operations)
[WARN] error reading pack 50209f8e (-> removing from index): Error: Data is too short (less than 16 bytes), cannot decrypt. (kind: related to cryptographic operations)

[…many more…]
$
```

That one was at least completing without crashing, but afterwards `check`
still crashed and `repair index` when run again still reported the same
problems.

The documentation warns against trying to continue doing backups if the
`check` command did not report a healthy repository, so my import was now
stalled and future backups not happening. I had spent two days trying to get
help on this but it was only the main author of `rustic` responding to me. I
started to become uncomfortable that if I had problems with my backups there
would be limited resources to help me out.

I decided to stop evaluating `rustic` at this point and spend more time with
`restic`, allowing for its shortcomings that I'd already identified (the path
names and specifying fake times things).

## A return to restic

Since I'd decided to start over again with `restic` I was prepared to destroy
the data in my `restic` repository that had been put in by `rustic`, that was
currently corrupt and unusable anyway. On reading the documentation for
`restic` it did suggest that running `repair snapshots` might sort things out.
Of course, they would never promise to support a repository with snapshots
that different softyware (`rustic`) had put into it, but I had nothing to
lose.

I ran `restic repair snapshots` and this claimed to work, after removing a few
of the partially-completed backups. A later `restic check` came back clean.

{% admonition_body(type="note", title="rustic most likely did nothing incorrect") %}

I want to stress that I've no reason to believe that I couldn't have fixed my
repository by running `rustic repair snapshots` and carried on using `rustic`.
I hadn't got as far as being suggested to run `repair snapshots` by the
`rustic` author. I also have no reason to be sure that `restic` would have
behaved any differently if I had allowed it to fill the filesystem of the
repository. The repository format is supposed to be compatible so they
probably would have behaved the same.

What made the difference, and what made me decide to carry on with `restic`
for now, is that the documentation and support available allowed me to feel
more confident in what I was doing.

{% end %}

I was able to see both from logs on the machines being backed up and from the
list of snapshots which ones had added the most data, and by doing a
`restic diff` between the snapshot tagged `rsnapshot_daily_0` and the most
recent snapshot for a given host tagged `auto` (the tag I was using for the
new, regular daily backups) I could see lots of things I had failed to
exclude.

It _is_ possible to tell `restic` to remove some paths from an existing
snapshot. It just makes a new snapshot without the specified data present and
then you tell it to `forget` and `prune` the original snaoshot(s). This
unwanted data was only in some of the previous night's snapshots tagged `auto`
though, so I just got rid of those snapshots entirely.

I was now ready to resume my imports and daily backups but I was still a
little paranoid about the health of the repository. `check` and every other
command I ran showed me sensible output and really I probably shouldn't have
been concerned because, well, this store is encrypted, right? If it was
corrupted I wouldn't be able to run `check` successfully nor be able to list
off the files within the snapshots.

As a compromise I decided to run the imports again but first:

1. Mark all existing imports with tag `suspect` so I could identify them
   later.
2. Plan to run new imports with extra tag `second_try`, again so they could be
   distinguished.

My thought here was that if I am importing the exact same data over again then
yes it will still take ages to read all of that, but as long as the data
that's in the repository already is still correct then `restic` is just going
to see the same data and not actually send it in.

### Dealing with the absolute path names

As mentioned, one of my major reasons for exploring `rustic` instead of
`restic` was so I could make the path names in the backups match. I wasn't
going to let this beat me.

Given that `restic` is a static binary it's extremely easy to run it in a
[chroot], because it just doesn't need much else besides the binary itself.
For example, let's say I want to back up the directories `etc/`, `home/` and
`src/` that are found within `/srv/rsnapshot/daily.0/foo.example.com/`, but I
want `restic` to think those directories are actually at `/`. I just have to
do this:

[chroot]: https://en.wikipedia.org/wiki/Chroot

```txt,name=terminal
# mount --bind /srv/rsnapshot/daily.0/foo.example.com /mnt/fake_restic_root
# cp /usr/local/sbin/restic /mnt/fake_restic_root/restic
# cp /usr/local/etc/restic/passwd /mnt/fake_restic_root/restic_passwd
# mkdir /mnt/fake_restic_root/tmp
# mount --bind /tmp /mnt/fake_restic_root/tmp
# chroot /mnt/fake_restic_root \
    /restic --insecure-tls \
        -r 'https://user:pass@192.168.10.20/'
        -p /restic_passwd \
        --verbose \
        backup \
            --host foo.example.com \
            --tag from_rsnapshot,rsnapshot_daily_0,second_try \
            /etc /home /srv
```

This is an abomination, but it works, and I only had to do it once. It made
`restic` see all the data directories as if they are rooted at `/`. Since I
hadn't set up `resolv.conf` or anything there's no DNS resolution so the
(remote) repository had to be specified by IP address. As there's no CA store
inside there the `--insecure-tls` flag had to be used[^1].

It wasn't hard to add that to my import script and set it going again.

### Dealing with the time faking

The other nicety of `rustic` was the ability to specify the fake backup time
on the command line. With `restic` I found it easier to just do the import and
then afterwards do:

```txt,name=terminal
$ for d in daily.*; do stat -c '%n %y' $d; done
daily.0 2025-08-17 21:03:22.000000000 +0000
daily.1 2025-08-16 20:45:51.000000000 +0000
daily.2 2025-08-15 21:00:44.000000000 +0000
daily.3 2025-08-14 20:46:47.000000000 +0000
daily.4 2025-08-13 20:51:27.000000000 +0000
daily.5 2025-08-12 21:50:05.000000000 +0000
daily.6 2025-08-11 20:33:44.000000000 +0000
```

I then had a script over on the repository server go through every snapshot
that was tagged both `rsnapshot_daily_0` and `second_try` and adjust its time
with the equivalent of:

```txt,name=terminal
$ sudo restic rewrite \
    --forget \
    --tag rsnapshot_daily_0,second_try \
    --new-time "2025-08-17 21:03:22"
```

and so on for each other interval.

It was easier to do this on the repository host because clients are accessing
the repository through a `rest-server` that is in append-only mode: they can't
actually `forget` and `prune` old snapshots.

### Import all done

Finally the import was all done and I was satisfied with it. I did a
`forget --prune` on all the snapshots tagged with `suspect` and had a look at
the new situation.

The 1.6 TiB of data from rsnapshot was all in `restic` where it took up
`920 GiB`.

## Memory usage can be problematic

Daily backups have been happening for a while now using `restic`. I have quite
a few low spec virtual machines that have only 1 GiB or 1.5 GiB of memory and
this has proven to be a problem. `restic` is using between 600 and 800 MiB
memory which is just too much for those timy VMs even though they don't have a
lot of data to back up.

Searching around I found [a recommendation] to set the environment variable
`GOGC=20`. That does seem to reduce usage by about 10% for me.

[a recommendation]:
  https://forum.restic.net/t/solved-restic-high-load-backup-killed/707/11

I was able to make it work on these low memory VMs by giving them another 1
GiB of swapfile. Obviously this isn't ideal as it makes the backup run take
longer, and also blows out the disk cache of the VM every night.

It's possible I may dare to go back to trying `rustic` on these VMs.

## TODO

### Pruning

I haven't yet set old backups to [expire]. That's basically going to be
something like this:

[expire]: https://restic.readthedocs.io/en/stable/060_forget.html

```txt,name=terminal
$ sudo restic forget \
    --tag from_rsnapshot \
    --group-by host \
    --keep-within-daily 8d \
    --keep-within-weekly 1m7d \
    --keep-within-monthly 13m \
    --keep-within-yearly 6y1m
$ sudo restic prune
```

(and then again for the `auto` tag.)

### Decide about the additional remote backups

There's more than one backup, except those are paused at the moment because
they all used to come out of `rsnapsbhot`. I need to decide about how to re-do
those. At least one of them probably should not be inside an opaque blob like
a `restic` repository.

### Use standard input for database backups

For things like databases I've generally been doing a daily dump into the
filesystem, compressing that with `gzip --rsyncable` and then backing that
file up. That works but it's not ideal as:

- It stores data twice on the filesystem
- It changes every time even when the database doesn't
- Even small changes in data produce large deltas in the `gzip`ped file

`restic` supports [backups directly from standard input]. That will solve the
above issues and will still be stored compressed in the repository.

[backups directly from standard input]:
  https://restic.readthedocs.io/en/stable/040_backup.html#reading-data-from-stdin

### Move to multiple repositories

I've come to the decision that a single `restic` repository for all hosts
being backed up is too risky from a security point of view.

The issue is that for the backup to be automated the repository secret key
must be on the client machine. If the client machine — _any_ client machine —
is compromised then the attacker has the secret key needed to decrypt the
backups for **absolutely everything**.

The append-only mode of the `rest-server` means that the attacker would be
unable to destroy the backup data, but having access to absolutely all data is
unacceptable.

The good news is that `rest-server` can talk to multiple repositories each
with its own keys. Client machines can have individual credentials and an
individual repository URL and they will not be able to access or decrypt
anything else.

The additional good news is that there's a `copy` command to copy snapshots
from one repository to another, so I can fairly easily reconfigure clients and
move their old snapshots over. I've started to do this.

The bad news of course is that there won't be any cross-host deduplication
after this. I'm going to have to live with that. There isn't any cross-host
deduplication in `rsnapshot` either; in fact there is no deduplication there
at all except for between exact path matches. If things went from 1.6 TiB in
`rsnapshot` to 920 GiB in a `restic` mega-repo then without cross-host
deduplication we could expect it to move a bit more towards 1.6 TiB, but not
all the way. Probably not all that far, actually. I shall report back.

It was running out of storage capacity that prompted all this in the first
place, but only because I wanted the new thing to be easier to manage. I don't
actually in principle have too much of an issue with 920 GiB inflating even
1.7x, though I would hope for less.

[^1]:
    Not hugely important since the stream is encrypted by `restic` anyway, and
    then encrypted again with TLS. The risk would be man-in-the-middle
    impersonation by IP address.
