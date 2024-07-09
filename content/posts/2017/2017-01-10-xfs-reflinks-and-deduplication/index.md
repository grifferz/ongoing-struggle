+++
title = "XFS, Reflinks and Deduplication"
description = """
Using reflinks in XFS for copy-on-write and deduplication
"""

[taxonomies]
# see `docs/tags_in_use.md` for a list of all tags currently in use.
tags = [
    "linux",
    "xfs",
]

[extra]
hide_from_feed = true
+++

{{ toc() }}

## `btrfs` Past

This post is about [`XFS`](https://en.wikipedia.org/wiki/Xfs), but it's _also_
about features that first hit Linux in
[`btrfs`](https://en.wikipedia.org/wiki/Btrfs), so we need to talk about
`btrfs` for a bit first.

For a long time now, btrfs has had a useful feature called reflinks. Basically
this is exposed as `cp --reflink=always` and takes advantage of extents and
copy-on-write in order to do a quick copy of data by merely adding another
reference to the extents that the data is currently using, rather than having
to read all the data and write it out again, as would be the case in other
filesystems.

Here's an excerpt from the
[man page for cp](http://man7.org/linux/man-pages/man1/cp.1.html):

> When `--reflink=[always]` is specified, perform a lightweight copy, where
> the data blocks are copied only when modified. If this is not possible the
> copy fails, or if `--reflink=auto` is specified, fall back to a standard
> copy.

Without reflinks a common technique for making a quick copy of a file is the
**hardlink**. Hardlinks have a number of disadvantages though, mainly due to
the fact that since there is only one inode all hardlinked copies must have
the same metadata (owner, group, permissions, etc.). Software that might
modify the files also needs to be aware of hardlinks: naive modification of a
hardlinked file modifies all copies of the file.

With reflinks, life becomes much easier:

- Each copy has its own inode so can have different metadata. Only the data
  extents are shared.
- The filesystem ensures that any write causes a copy-on-write, so
  applications don't need to do anything special.
- Space is saved on a per-extent basis so changing one extent still allows all
  the other extents to remain shared. A change to a hardlinked file requires a
  new copy of the whole file.

Another feature that extents and copy-on-write allow is block-level
out-of-band deduplication.

- **Deduplication** - the technique of finding and removing duplicate copies
  of data.
- **Block-level** - operating on the blocks of data on storage, not just whole
  files.
- **Out-of-band** - something that happens only when triggered or scheduled,
  not automatically as part of the normal operation of the filesystem.

`btrfs` has an [`ioctl`](https://en.wikipedia.org/wiki/Ioctl) that a userspace
program can use — presumably after finding a sequence of blocks that are
identical — to tell the kernel to turn one into a reference to the other, thus
saving some space.

It's necessary that the kernel does it so that any IO that may be going on at
the same time that may modify the data can be dealt with. Modifications after
the data is reflinked will just case a copy-on-write. If you tried to do it
all in a userspace app then you'd risk something else modifying the files at
the same time, but by having the kernel do it then in theory it becomes
completely safe to do it at any time. The kernel also checks that the sequence
of extents really _are_ identical.

In-band deduplication is a feature that's being worked on in `btrfs`. It
already exists in [`ZFS`](https://en.wikipedia.org/wiki/ZFS) though, and there
it is rarely recommended for use as it requires a huge amount of memory for
keeping hashes of data that has been written. It's going to be the same story
with btrfs, so out-of-band deduplication is still something that will remain
useful. And it exists as a feature right now, which is always a bonus.

## `XFS` Future

So what has all this got to do with `XFS`?

Well, in recognition that there might be more than one Linux filesystem with
extents and so that reflinks might be more generally useful, the extent-same
`ioctl` got lifted up to be in
[the VFS layer of the kernel](http://www.ibm.com/developerworks/library/l-virtual-filesystem-switch/)
instead of just in `btrfs`. And the good news is that `XFS` recently became
able to make use of it.

When I say "recently" I do mean really recently. I mean like kernel release
4.9.1 which came out on 2017-01-04. At the moment it comes with massive
**EXPERIMENTAL** warnings, requires a new filesystem to be created with a
special format option, and will need an `xfsprogs` compiled from
[recent git](https://xfs.wiki.kernel.org/#userspace_utilities) in order to
have a `mkfs.xfs` that can create such a filesystem.

So before going further, I'm going to assume you've compiled a new enough
kernel and booted into it, then compiled up a new enough `xfsprogs`. Both of
these are quite simple things to do, for example
[the Debian documentation for building kernel packages from upstream](https://www.debian.org/doc/manuals/debian-kernel-handbook/ch-common-tasks.html#s-kernel-org-package)
code works fine.

## XFS Reflink Demo

Make yourself a new filesystem, with the `reflink=1` format option.

```txt
# mkfs.xfs -L reflinkdemo -m reflink=1 /dev/xvdc
meta-data=/dev/xvdc              isize=512    agcount=4, agsize=3276800 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=0, rmapbt=0, reflink=1
data     =                       bsize=4096   blocks=13107200, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=6400, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
```

Put it in `/etc/fstab` for convenience, and mount it somewhere.

```txt
# echo "LABEL=reflinkdemo /mnt/xfs xfs relatime 0 2" >> /etc/fstab
# mkdir -vp /mnt/xfs
mkdir: created directory ‘/mnt/xfs’
# mount /mnt/xfs
# df -h /mnt/xfs
Filesystem      Size  Used Avail Use% Mounted on
/dev/xvdc        50G  339M   50G   1% /mnt/xfs
```

Create a few files with random data.

```txt
# mkdir -vp /mnt/xfs/reflink
mkdir: created directory ‘/mnt/xfs/reflink’
# chown -c andy: /mnt/xfs/reflink
changed ownership of ‘/mnt/xfs/reflink’ from root:root to andy:andy
# exit
$ for i in {1..5}; do
> echo "Writing $i…"; dd if=/dev/urandom of=/mnt/xfs/reflink/$i bs=1M count=1024;
> done
Writing 1…
1024+0 records in
1024+0 records out
1073741824 bytes (1.1 GB) copied, 4.34193 s, 247 MB/s
Writing 2…
1024+0 records in
1024+0 records out
1073741824 bytes (1.1 GB) copied, 4.33207 s, 248 MB/s
Writing 3…
1024+0 records in
1024+0 records out
1073741824 bytes (1.1 GB) copied, 4.33527 s, 248 MB/s
Writing 4…
1024+0 records in
1024+0 records out
1073741824 bytes (1.1 GB) copied, 4.33362 s, 248 MB/s
Writing 5…
1024+0 records in
1024+0 records out
1073741824 bytes (1.1 GB) copied, 4.32859 s, 248 MB/s
$ df -h /mnt/xfs
Filesystem      Size  Used Avail Use% Mounted on
/dev/xvdc        50G  5.4G   45G  11% /mnt/xfs
$ du -csh /mnt/xfs
5.0G    /mnt/xfs
5.0G    total
```

Copy a file and as expected usage will go up by 1GiB. And it will take a
little while, even on my nice fast SSDs.

```txt
$ time cp -v /mnt/xfs/reflink/{,copy_}1
‘/mnt/xfs/reflink/1’ -> ‘/mnt/xfs/reflink/copy_1’

real    0m3.420s
user    0m0.008s
sys     0m0.676s
$ df -h /mnt/xfs; du -csh /mnt/xfs/reflink
Filesystem      Size  Used Avail Use% Mounted on
/dev/xvdc        50G  6.4G   44G  13% /mnt/xfs
6.0G    /mnt/xfs/reflink
6.0G    total
```

So what about a reflink copy?

```txt
$ time cp -v --reflink=always /mnt/xfs/reflink/{,reflink_}1
‘/mnt/xfs/reflink/1’ -> ‘/mnt/xfs/reflink/reflink_1’

real    0m0.003s
user    0m0.000s
sys     0m0.004s
$ df -h /mnt/xfs; du -csh /mnt/xfs/reflink
Filesystem      Size  Used Avail Use% Mounted on
/dev/xvdc        50G  6.4G   44G  13% /mnt/xfs
7.0G    /mnt/xfs/reflink
7.0G    total
```

The apparent usage went up by 1GiB but the amount of free space as shown by
`df` stayed the same. No more actual storage was used because the new copy is
a reflink. And the copy got done in 4ms as opposed to 3,420ms.

Can we tell more about how these files are laid out? Yes, we can use the
`filefrag -v` command to tell us more.

```txt
$ filefrag -v /mnt/xfs/reflink/{,copy_,reflink_}1
Filesystem type is: 58465342
File size of /mnt/xfs/reflink/1 is 1073741824 (262144 blocks of 4096 bytes)
 ext:     logical_offset:        physical_offset: length:   expected: flags:
   0:        0..  262143:    1572884..   1835027: 262144:             last,shared,eof
/mnt/xfs/reflink/1: 1 extent found
File size of /mnt/xfs/reflink/copy_1 is 1073741824 (262144 blocks of 4096 bytes)
 ext:     logical_offset:        physical_offset: length:   expected: flags:
   0:        0..  262143:     917508..   1179651: 262144:             last,eof
/mnt/xfs/reflink/copy_1: 1 extent found
File size of /mnt/xfs/reflink/reflink_1 is 1073741824 (262144 blocks of 4096 bytes)
 ext:     logical_offset:        physical_offset: length:   expected: flags:
   0:        0..  262143:    1572884..   1835027: 262144:             last,shared,eof
/mnt/xfs/reflink/reflink_1: 1 extent found
```

What we can see here is that all three files are composed of a single extent
which is 262,144 4KiB blocks in size, but it also tells us that
`/mnt/xfs/reflink/1` and `/mnt/xfs/reflink/reflink_1` are using the same range
of physical blocks: 1572884..1835027.

## XFS Deduplication Demo

We've demonstrated that you can use `cp --reflink=always` to take a cheap copy
of your data, but what about data that may already be duplicates without your
knowledge? Is there any way to take advantage of the extent-same `ioctl` for
deduplication?

There's a couple of
[software solutions for out-of-band deduplication in `btrfs`](https://btrfs.wiki.kernel.org/index.php/Deduplication),
but one I know that works also in XFS is
[`duperemove`](https://github.com/markfasheh/duperemove). You will need to use
a git checkout of `duperemove` for this to work.

A quick reminder of the storage use before we start.

```txt
$ df -h /mnt/xfs; du -csh /mnt/xfs/reflink
Filesystem      Size  Used Avail Use% Mounted on
/dev/xvdc        50G  6.4G   44G  13% /mnt/xfs
7.0G    /mnt/xfs/reflink
7.0G    total
$ filefrag -v /mnt/xfs/reflink/{,copy_,reflink_}1
Filesystem type is: 58465342
File size of /mnt/xfs/reflink/1 is 1073741824 (262144 blocks of 4096 bytes)
 ext:     logical_offset:        physical_offset: length:   expected: flags:
   0:        0..  262143:    1572884..   1835027: 262144:             last,shared,eof
/mnt/xfs/reflink/1: 1 extent found
File size of /mnt/xfs/reflink/copy_1 is 1073741824 (262144 blocks of 4096 bytes)
 ext:     logical_offset:        physical_offset: length:   expected: flags:
   0:        0..  262143:     917508..   1179651: 262144:             last,eof
/mnt/xfs/reflink/copy_1: 1 extent found
File size of /mnt/xfs/reflink/reflink_1 is 1073741824 (262144 blocks of 4096 bytes)
 ext:     logical_offset:        physical_offset: length:   expected: flags:
   0:        0..  262143:    1572884..   1835027: 262144:             last,shared,eof
/mnt/xfs/reflink/reflink_1: 1 extent found
```

Run `duperemove`.

```
# duperemove -hdr --hashfile=/var/tmp/dr.hash /mnt/xfs/reflink
Using 128K blocks
Using hash: murmur3
Gathering file list...
Adding files from database for hashing.
Loading only duplicated hashes from hashfile.
Using 2 threads for dedupe phase
Kernel processed data (excludes target files): 4.0G
Comparison of extent info shows a net change in shared extents of: 1.0G
$ df -h /mnt/xfs; du -csh /mnt/xfs/reflink
Filesystem      Size  Used Avail Use% Mounted on
/dev/xvdc        50G  5.4G   45G  11% /mnt/xfs
7.0G    /mnt/xfs/reflink
7.0G    total
$ filefrag -v /mnt/xfs/reflink/{,copy_,reflink_}1
Filesystem type is: 58465342
File size of /mnt/xfs/reflink/1 is 1073741824 (262144 blocks of 4096 bytes)
 ext:     logical_offset:        physical_offset: length:   expected: flags:
   0:        0..  262143:    1572884..   1835027: 262144:             last,shared,eof
/mnt/xfs/reflink/1: 1 extent found
File size of /mnt/xfs/reflink/copy_1 is 1073741824 (262144 blocks of 4096 bytes)
 ext:     logical_offset:        physical_offset: length:   expected: flags:
   0:        0..  262143:    1572884..   1835027: 262144:             last,shared,eof
/mnt/xfs/reflink/copy_1: 1 extent found
File size of /mnt/xfs/reflink/reflink_1 is 1073741824 (262144 blocks of 4096 bytes)
 ext:     logical_offset:        physical_offset: length:   expected: flags:
   0:        0..  262143:    1572884..   1835027: 262144:             last,shared,eof
/mnt/xfs/reflink/reflink_1: 1 extent found
```

The output of `du` remained the same, but `df` says that there's now 1GiB more
free space, and `filefrag` confirms that what's changed is that `copy_1` now
uses the same extents as `1` and `reflink_1`. The duplicate data in `copy_1`
that in theory we did not know was there, has been discovered and safely
reference-linked to the extent from `1`, saving us 1GiB of storage.

By the way, I told `duperemove` to use a hash file because otherwise it will
keep that in RAM. For the sake of 7 files that won't matter but it will if I
have millions of files so it's a habit I get into. It uses that hash file to
avoid having to repeatedly re-hash files that haven't changed.

All that has been demonstrated so far though is whole-file deduplication, as
`copy_1` was just a regular copy of `1`. What about when a file is only
_partially_ composed of duplicate data? Well okay.

```txt
$ cat /mnt/xfs/reflink/{1,2} > /mnt/xfs/reflink/1_2
$ ls -lah /mnt/xfs/reflink/{1,2,1_2}
-rw-r--r-- 1 andy andy 1.0G Jan 10 15:41 /mnt/xfs/reflink/1
-rw-r--r-- 1 andy andy 2.0G Jan 10 16:55 /mnt/xfs/reflink/1_2
-rw-r--r-- 1 andy andy 1.0G Jan 10 15:41 /mnt/xfs/reflink/2
$ df -h /mnt/xfs; du -csh /mnt/xfs/reflink
Filesystem      Size  Used Avail Use% Mounted on
/dev/xvdc        50G  7.4G   43G  15% /mnt/xfs
9.0G    /mnt/xfs/reflink
9.0G    total
$ filefrag -v /mnt/xfs/reflink/{1,2,1_2}
Filesystem type is: 58465342
File size of /mnt/xfs/reflink/1 is 1073741824 (262144 blocks of 4096 bytes)
 ext:     logical_offset:        physical_offset: length:   expected: flags:
   0:        0..  262143:    1572884..   1835027: 262144:             last,shared,eof
/mnt/xfs/reflink/1: 1 extent found
File size of /mnt/xfs/reflink/2 is 1073741824 (262144 blocks of 4096 bytes)
 ext:     logical_offset:        physical_offset: length:   expected: flags:
   0:        0..  262127:         20..    262147: 262128:
   1:   262128..  262143:    2129908..   2129923:     16:     262148: last,eof
/mnt/xfs/reflink/2: 2 extents found
File size of /mnt/xfs/reflink/1_2 is 2147483648 (524288 blocks of 4096 bytes)
 ext:     logical_offset:        physical_offset: length:   expected: flags:
   0:        0..  262127:     262164..    524291: 262128:
   1:   262128..  524287:     655380..    917539: 262160:     524292: last,eof
/mnt/xfs/reflink/1_2: 2 extents found
```

I've concatenated `1` and `2` together into a file called `1_2` and as
expected, usage goes up by 2GiB. `filefrag` confirms that the physical extents
in `1_2` are new. We should be able to do better because this `1_2` file does
not contain any new unique data.

```txt
$ duperemove -hdr --hashfile=/var/tmp/dr.hash /mnt/xfs/reflink
Using 128K blocks
Using hash: murmur3
Gathering file list...
Adding files from database for hashing.
Using 2 threads for file hashing phase
Kernel processed data (excludes target files): 4.0G
Comparison of extent info shows a net change in shared extents of: 3.0G
$ df -h /mnt/xfs; du -csh /mnt/xfs/reflink
Filesystem      Size  Used Avail Use% Mounted on
/dev/xvdc        50G  5.4G   45G  11% /mnt/xfs
9.0G    /mnt/xfs/reflink
9.0G    total
```

We can. Apparent usage stays at 9GiB but real usage went back to 5.4GiB which
is where we were before we created **1_2**.

And the physical layout of the files?

```txt
$ filefrag -v /mnt/xfs/reflink/{1,2,1_2}
Filesystem type is: 58465342
File size of /mnt/xfs/reflink/1 is 1073741824 (262144 blocks of 4096 bytes)
 ext:     logical_offset:        physical_offset: length:   expected: flags:
   0:        0..  262143:    1572884..   1835027: 262144:             last,shared,eof
/mnt/xfs/reflink/1: 1 extent found
File size of /mnt/xfs/reflink/2 is 1073741824 (262144 blocks of 4096 bytes)
 ext:     logical_offset:        physical_offset: length:   expected: flags:
   0:        0..  262127:         20..    262147: 262128:             shared
   1:   262128..  262143:    2129908..   2129923:     16:     262148: last,shared,eof
/mnt/xfs/reflink/2: 2 extents found
File size of /mnt/xfs/reflink/1_2 is 2147483648 (524288 blocks of 4096 bytes)
 ext:     logical_offset:        physical_offset: length:   expected: flags:
   0:        0..  262143:    1572884..   1835027: 262144:             shared
   1:   262144..  524271:         20..    262147: 262128:    1835028: shared
   2:   524272..  524287:    2129908..   2129923:     16:     262148: last,shared,eof
/mnt/xfs/reflink/1_2: 3 extents found
```

It shows that `1_2` is now made up from the same extents as `1` and `2`
combined, as expected.

## Less of the `urandom`

These synthetic demonstrations using a handful of 1GiB blobs of data from
`/dev/urandom` are all very well, but what about something a little more like
the real world?

Okay well let's see what happens when I take ~30GiB of backup data created by
[`rsnapshot`](http://rsnapshot.org/) on another host.

`rsnapshot` is a backup program which makes heavy use of hardlinks. It runs
periodically and compares the previous backup data with the new. If they are
identical then instead of storing an identical copy it makes a hardlink. This
saves a lot of space but does have a lot of limitations as discussed
previously.

This won't be the best example because in some ways there is expected to be
more duplication; this data is composed of multiple backups of the same file
trees. But on the other hand there shouldn't be as much because any truly
identical files have already been hardlinked together by `rsnapshot`. But it
is a convenient source of real-world data.

So, starting state:

(I deleted all the reflink files)

```txt
$ df -h /mnt/xfs; sudo du -csh /mnt/xfs/rsnapshot
Filesystem      Size  Used Avail Use% Mounted on
/dev/xvdc        50G   30G   21G  59% /mnt/xfs
29G     /mnt/xfs/rsnapshot
29G     total

```

### `rsnapshot` repository layout

A small diversion about how `rsnapshot` lays out its backups may be useful
here. They are stored like this:

- rsnapshot_root / \[iteration a\] / \[client foo\] / \[directory structure
  from client foo\]
- rsnapshot_root / \[iteration a\] / \[client bar\] / \[directory structure
  from client bar\]
- …
- …
- rsnapshot_root / \[iteration b\] / \[client foo\] / \[directory structure
  from client foo\]
- rsnapshot_root / \[iteration b\] / \[client bar\] / \[directory structure
  from client bar\]

The iterations are commonly things like _daily.0_, _daily.1_ … _daily.6_. As a
consequence, the paths:

> rsnapshot/daily.\*/client_foo

would be backups only from host _foo_, and:

> rsnapshot/daily.0/\*

would be backups from all hosts but only the most recent daily sync.

Let's first see what the savings would be like in looking for duplicates in
just one client's backups.

Here's the backups I have in this blob of data. The names of the clients are
completely made up, though they are real backups.

| Client | Size (MiB) |
| ------ | ---------- |
| darbee | 14,504     |
| achorn | 11,297     |
| spader | 2,612      |
| reilly | 2,276      |
| chino  | 2,203      |
| audun  | 2,184      |

So let's try deduplicating all of the biggest one's — `darbee`'s — backups:

```txt
$ df -h /mnt/xfs
Filesystem      Size  Used Avail Use% Mounted on
/dev/xvdc        50G   30G   21G  59% /mnt/xfs
# time duperemove -hdr --hashfile=/var/tmp/dr.hash /mnt/xfs/rsnapshot/*/darbee
Using 128K blocks
Using hash: murmur3
Gathering file list...
Kernel processed data (excludes target files): 8.8G
Comparison of extent info shows a net change in shared extents of: 6.8G
9.85user 78.70system 3:27.23elapsed 42%CPU (0avgtext+0avgdata 23384maxresident)k
50703656inputs+790184outputs (15major+20912minor)pagefaults 0swaps
$ df -h /mnt/xfs
Filesystem      Size  Used Avail Use% Mounted on
/dev/xvdc        50G   25G   26G  50% /mnt/xfs
```

3m27s of run time, somewhere between 5 and 6.8GiB saved. That's 35%!

Now to deduplicate the lot.

```txt
# time duperemove -hdr --hashfile=/var/tmp/dr.hash /mnt/xfs/rsnapshot
Using 128K blocks
Using hash: murmur3
Gathering file list...
Kernel processed data (excludes target files): 5.4G
Comparison of extent info shows a net change in shared extents of: 3.4G
29.12user 188.08system 5:02.31elapsed 71%CPU (0avgtext+0avgdata 34040maxresident)k
34978360inputs+572128outputs (18major+45094minor)pagefaults 0swaps
$ df -h /mnt/xfs
Filesystem      Size  Used Avail Use% Mounted on
/dev/xvdc        50G   23G   28G  45% /mnt/xfs
```

5m02 used this time, and another 2–3.4G saved.

Since the actual deduplication does take some time (the kernel having to read
the extents, mainly), and most of it was already done in the first pass, a
full pass would more likely take the sum of the times, i.e. more like 8m29s.

Still, a total of about 7GiB was saved which is 23%.

It would be very interesting to try this on one of my much larger backup
stores.

## Why Not Just Use `btrfs`?

Using a filesystem that already has all of these features would certainly seem
easier, but I personally don't think `btrfs` is stable enough yet. I use it at
home in a relatively unexciting setup (8 devices, RAID-1 profile for data and
metadata, no compression or deduplication) and I wish I didn't. I wouldn't
dream of using it in a production environment yet.

I'm on the `btrfs` mailing list and there are way too many posts regarding
filesystems that give `ENOSPC` and become unavailable for writes, or systems
that were unexpectedly powered off and when powered back on the `btrfs`
filesystem is completely lost.

I expect the reflink feature in `XFS` to become non-experimental before I'd be
happy that `btrfs` is stable enough for production use.

## `ZFS`?

`ZFS` is great. It doesn't have out-of-band deduplication or reflinks though,
and
[they don't plan to any time soon](https://github.com/zfsonlinux/zfs/issues/405).
