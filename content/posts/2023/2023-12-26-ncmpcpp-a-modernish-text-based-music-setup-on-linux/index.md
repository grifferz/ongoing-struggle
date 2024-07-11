+++
title = "ncmpcpp — A Modern(ish) Text-Based Music Setup On Linux"
description = """
How I've ended up (back) on the terminal-based music player ncmpcpp on my GNOME
Linux desktop and laptop. I cover why it is that this has happened, and some of
the finer points of the configuration.
"""

[taxonomies]
# see `docs/tags_in_use.md` for a list of all tags currently in use.
tags = [
    "debian",
    "gnome",
    "linux",
    "migrated-from-wordpress",
]

[extra]
hide_from_feed = true
+++

{{ toc() }}

## Preface

This article is about how I've ended up (back) on the terminal-based music
player [`ncmpcpp`](https://github.com/ncmpcpp/ncmpcpp) on my GNOME Linux
desktop and laptop. I'll cover why it is that this has happened, and some of
the finer points of the configuration. The
[various scripts are available at GitHub](https://github.com/grifferz/ncmpcpp-setup).
My thing now looks like this:

{{ figure(
    class="captioned",
    src="images/Screenshot-from-2023-12-26-13-09-47.png",
    alt="A screenshot of my ncmpcpp setup running in a kitty terminal, with a
        track change notification visible in the top right corner",
    caption="A screenshot of my ncmpcpp setup running in a kitty terminal, with
        a track change notification visible in the top right corner"
) }}

These sorts of things are inherently personal. I don't expect that most people
would have my requirements — the lack of functioning software that caters for
them must indicate that — but if you do, or if you're just interested in
seeing what a modern text interface player can do on Linux, maybe you will be
interested in what I came up with.

## My Requirements

I'm one of those strange old-fashioned people who likes owning the music I
regularly play, instead of just streaming everything, always. I don't mind
doing a stream search to play something on a whim or to check out new music,
but if I think I'll want to listen to it again then I want to own a copy of
it. So I also need something to play music with.

I thought I had simple requirements.

### Essential

- **Fill a play queue randomly by album**, i.e. queue entire albums at once
  until some target number of tracks are in the queue. The sort of thing
  that's often called a "dynamic playlist" or a "smart playlist" these days.
- **Have working media keys**, i.e. when I press the Play/Pause button or the
  Next button on my keyboard, that actually happens.

That's it. Those are my essential requirements.

### Nice to have

- Have album cover art displayed.
- Have desktop notifications show up announcing a new track being played.

## Ancient history

Literally decades ago these needs were met by the likes of Winamp and Amarok;
software that's now consigned to history. Still more than a decade ago on
desktop Linux I looked around and couldn't easily find what I wanted from any
of the music apps. I settled on putting my music in
[`mpd`](https://www.musicpd.org/) and using an `mpd` client to play it,
because that way it was fairly easy to write a script for a dynamic play queue
that worked exactly how I wanted it to — the most important requirement.

For a while I used a terminal-based `mpd` client called `ncmpcpp`. I'm very
comfortable in a Linux terminal so this wasn't alien to me. It's very pleasant
to use, but being text-based it doesn't come with the niceties of media key
support, album cover art or desktop notifications. The `mpd` client that I
settled upon was GNOME's built-in
[gmpc](https://github.com/DaveDavenport/gmpc). It's a very basic player but
all it had to do was show the play queue that `mpd` had provided, and do the
media keys, album art and notifications.

## Change Is Forced Upon Me

Fast forward to December 2023 and I found myself desperately needing to
upgrade my Ubuntu 18.04 desktop machine. I switched to Debian 12, which
brought with it a new major version of GNOME as well as using Wayland instead
of Xorg. And I found that **gmpc** didn't work correctly any more! The media
keys weren't doing anything (they work fine in everything else), and I didn't
like the notifications.

I checked out a wide range of media players again. I'm talking Rhythmbox,
Clementine, Raspberry, Quod Libet and more. Some of them clearly didn't do the
play queue thing. Others might do, but were incomprehensible to me and lacking
in documentation. I think the nearest might have been Rhythmbox which has a
plugin that can queue a specified number of random albums. There is an 11 year
old GitHub issue asking for it to just continually queue such albums. A bit
clunky without that.

I expect some reading this are now shouting at their screens about how their
favourite player _does_ actually do what I want. It's quite possible I was too
ignorant to notice it or work out how. Did I mention that quite a lot of this
software is not documented at all? Seriously, major pieces of software that
just have a web site that is a set of screenshots and a bulleted feature list
and …that's _it_. I had
[complained about this on Fedi](https://social.bitfolk.com/@grifferz/111617974372701469)
and got some suggestions for things to try, which I will (and I'll check out
any that are suggested here), but the thing is… I **know** how shell scripts
work _now_. 😀

## This Is The Way

I had a look at `ncmpcpp` again. I still enjoyed using it. I was able to see
how I could get the niceties after all. This is how.

## Required Software

Here's the software I needed to install to make this work on Debian 12. I'm
not going to particularly go into the configuration of Debian, GNOME, `mpd` or
`ncmpcpp` because it doesn't really matter how you set those up. Just first
get to the point where your music is in `mpd` and you can start `ncmpcpp` to
play it.

### Packaged in Debian

- `mpd`
- `mpc`
- `ncmpcpp`
- `kitty`
- `timg`
- `libnotify-bin`
- `inotify-tools`

So:

```txt
$ apt install mpd mpc ncmpcpp kitty timg libnotify-bin inotify-tools
```

In case you weren't aware, you can arrange for your personal `mpd` to be
started every time you start your desktop environment like this:

```txt
$ systemctl --user enable --now mpd
```

The `--now` flag both enables the service and starts it right away.

{% admonition_body(type="warning") %}

This command isn't run as `root`; it's a user-level `systemd` service hence
the `--user` option.

{% end %}

At this point you should have `mpd` running and serving your music collection
to any mpd client that connects. You can verify this with **gmpc** which is a
very simple graphical `mpd` client.

### Not currently packaged in Debian

#### [mpd-mpris](https://github.com/natsukagami/mpd-mpris)

This small Go binary listens on the user DBUS for the media keys and issues
mpd commands appropriately. If you didn't want to use this then you could lash
up something very simple that executes e.g. `mpc next` or `mpc toggle` when
the relevant key is pressed, but this does it all for you. Once you've
[got it from GitHub](https://github.com/natsukagami/mpd-mpris) place the
binary in **$HOME/bin/**,
[the mpd-mpris.service file from my GitHub](https://github.com/grifferz/ncmpcpp-setup/blob/main/mpd-mpris.service)
at **$HOME/.config/systemd/user/mpd-mpris.service** and issue:

```txt
$ systemctl --user enable --now mpd-mpris
```

Assuming you have a running `mpd` and `mpd` client your media keys should now
control it. Test that with **gmpc** or whatever.

### My scripts and supporting files

Just four files, and they are
[all in GitHub](https://github.com/grifferz/ncmpcpp-setup). Here's what to do
with them.

#### [album_cover_poller.sh](https://github.com/grifferz/ncmpcpp-setup/blob/main/album_cover_poller.sh)

Put it in **$HOME/.ncmpcpp/**. It shouldn't need editing.

#### [default_cover.jpg](https://github.com/grifferz/ncmpcpp-setup/blob/main/default_cover.jpg)

Put it in **$HOME/.ncmpcpp/**. If you don't like it, just substitute it with
any other you like. When it comes time for `timg` to display it, it will scale
it to fit inside the window whatever size it is on your desktop.

#### [track_change.sh](https://github.com/grifferz/ncmpcpp-setup/blob/main/track_change.sh)

Put it in **$HOME/.ncmpcpp/**. You'll need to change `candidate_name` near the
top if your album cover art files aren't called **cover.jpg**.

#### [viz.conf](https://github.com/grifferz/ncmpcpp-setup/blob/main/viz.conf)

Put it in **$HOME/.ncmpcpp/**. This is a cut-down example `ncmpcpp` config for
the visualizer pane that removes a number of UI elements. It's just for an
`ncmpcpp` that starts on a visualizer view so feel free to customise it
however you like your visualizer to be. You will need to change
`mpd_music_dir` to match where your music is, like in your main `ncmpcpp`
config.

## The Main App

The main app displayed in the screenshot above is a `kitty` terminal with
three windows. The leftmost 75% of the `kitty` terminal runs `ncmpcpp`
defaulting to the playlist view. In the bottom right corner is a copy of
`ncmpcpp` defaulting to the visualizer view and using the **viz.conf**. The
top right corner is running a shell script that polls for album covert art and
displays it in the terminal.

`kitty` is one of the newer crop of terminals that can display graphics. The
`timg` program will detect `kitty`'s graphics support and display a proper
graphical image. In the absence of `kitty`'s graphical protocol `timg` will
fall back to [sixel](https://en.wikipedia.org/wiki/Sixel) mode, which may be
discernible but I wouldn't personally want to use it.

I don't actually use `kitty` as my day-to-day terminal. I use `gnome-terminal`
and `tmux`. You can make a layout like this with `gnome-terminal` and `tmux`,
or even `kitty` and `tmux`, but `tmux` doesn't support `kitty`'s graphical
protocol so it would cause a fall back to sixel mode. So for this use and this
use alone I use `kitty` and its built-in windowing support.

{{ figure(
    class="captioned",
    src="images/good-vibrations.png",
    alt="Album cover art for Good Vibrations: Thirty Years of The Beach Boys
        displayed in a kitty terminal using timg",
    caption="Album cover art for Good Vibrations: Thirty Years of The Beach
        Boys displayed in a kitty terminal using timg"
) }}

{{ figure(
    class="captioned",
    src="images/good-vibrations-sixel.png",
    alt="The same cover art file displayed as sixels through tmux",
    caption="The same cover art file displayed as sixels through tmux"
) }}

If you don't want to use `kitty` then pick whatever terminal you like and
figure out how to put some different windows in it (`tmux` panes work fine,
layout-wise). `timg` will probably fall back to sixels as even the venerable
`xterm` supports that. But assuming you _are_ willing to use `kitty`, you can
start it like this:

```txt
$ kitty -o font_size=16 --session ~/.config/kitty/ncmpcpp.session
```

That `kitty` session file is
[in GitHub with everything else](https://github.com/grifferz/ncmpcpp-setup/blob/main/ncmpcpp.session),
and it's what lays things out in the main terminal window. You should now be
able to start playing music in `ncmpcpp` and have everything work.

## How Stuff Works

You don't need to know how it works, but in case you care I will explain a
bit.

There are two bash shell scripts; **album_cover_poller.sh** and
**track_change.sh**.

### Album cover art

**album_cover_poller.sh** uses **inotifywait** from the
[inotify-tools](https://packages.debian.org/bookworm/inotify-tools) package to
watch a file in a cache directory. Any time that file changes, it uses `timg`
to display it in the upper right window and queries mpd for the meta data of
the currently-playing track.

### Track change tasks

**track_change.sh** is a bit more involved.

`ncmpcpp` is made to execute it when it changes track by adding this to your
`ncmpcpp` configuration:

```txt
execute_on_song_change = "~/.ncmpcpp/track_change.sh -m /path/to/your/music/dir"
```

The `/path/to/your/music/dir` should be the same as what you have set your
music library to in your `mpd` config. It defaults to **$HOME/Music/** if not
set.

First it asks `mpd` for a bunch of metadata about the currently-playing track.
Using that it's able to find the directory in the filesystem where the track
file lives. It assumes that if album cover art is available then it will be in
this directory and named **cover.jpg**. If it finds such a file then it copies
it to the place where **album_cover_poller.sh** is expecting to find it. That
will trigger that script's **inotifywait** to display the new image. If it
doesn't find such a file then a default generic cover art image is used.

(A consequence of this is that it expects each directory in your music library
to be for an album, with the **cover.jpg** being the album covert art. It
intentionally doesn't try to handle layouts like **Artist/Track.ogg** because
it hasn't got a way to know which file would be for that album. If you use
some other layout I'd be interested in hearing about it. An obvious
improvement would be to have it look inside each file's metadata for art in
the absence of a **cover.jpg** in the directory. That would be pretty easy,
but it's not relevant for my use at the moment.)

Secondly, a desktop notification is sent using `notify-send`. Most modern
desktops including GNOME come with support for showing such notifications.
Exactly how they look and the degree to which you can configure that depends
upon your desktop environment. For GNOME, the answer is "_like ass_", and
"_not at all without changing notification daemon_," but that's the case for
every notification on the system so is a bit out of scope for this article.

## Other Useful Tools

I use a few other bits of software to help manage my music collection and play
things nicely, that aren't directly relevant to this.

### Library maintenance

A good experience relies on there being correct metadata and files in the
expected directory structure. It's pretty common for music I buy to have junk
metadata, and moving things into place would be tedious even when the metadata
is correct. [MusicBrainz Picard](https://picard.musicbrainz.org/) to the
rescue!

It's great at fixing metadata and then moving files en masse to my chosen
directory structure. It can even be told for example that if the current track
artist differs from the album artist then it should save the file out to
"${album\_artist}/${track_number}-${track\_artist}-${track title}.mp3" so that
a directory listing of a large "Various Artists" compilation album looks nice.

It also finds and saves album cover art for me.

It's packaged in Debian.

I hear good things about [beets](https://beets.readthedocs.io/en/stable/),
too, but have never tried it.

### Album cover art

Picard is pretty good at finding album cover art but sometimes it can't manage
it, or it chooses sub-par images. I like the Python app
[`sacad`](https://github.com/desbma/sacad) which tries really hard to find
good quality album art and works on masses of directories at once.

### Nicer desktop notifications

I really don't like the default GNOME desktop notifications. On a 4K display
they are tiny unless you crank up the general font size, in which case your
entire desktop then looks like a toddler's toy. Not only is their text tiny
but they don't hold much content either. When most track title notifications
are ellipsized I start to wonder what the point is.

I replaced GNOME's notification daemon with
[wired-notify](https://github.com/Toqozz/wired-notify), which is extremely
configurable. I did have to clone it out of GitHub, install the rust toolchain
and `cargo build` it, however.

My track change script that I talk about above will issue notifications that
work on stock GNOME just as well as any other app's notifications, but I
prefer the wired-notify ones. Here's an unscaled example.

{{ figure(
    class="captioned",
    src="images/ncmpcpp-notif.png",
    alt="A close up of a notification from track_change.sh",
    caption="A close up of a notification from track_change.sh"
) }}

It's not a work of art by any means, but is so much better than the default
experience. There's
[a bunch of other people's configs showcased on their GitHub](https://github.com/Toqozz/wired-notify/issues/63).

### Scrobbling

[mpdscribble](https://github.com/MusicPlayerDaemon/mpdscribble) has got you
covered for [last.fm](https://www.last.fm/) and [Libre.fm](https://libre.fm/).
Again it is already packaged in Debian.

## Shortcomings

If there's any music files with tabs or newlines in any of their metadata, the
scripts are going to blow up. I'm not sure of the best way to handle that one.
`mpc` can't format output NULL-separated like you'd do with GNU `find`. I'm
not sure there is any character you can make it use in a format that is banned
in metadata. I think worst case is simply messed up display and/or no cover
art displayed, and I'd regard tabs and newlines in track metadata as a data
error that I'd want to fix, so maybe I don't care too much.

`timg` is supposed to scale and centre the image in the terminal, and the
`kitty` window does resize to keep it at 25% width, 50% height, but `timg` is
sometimes visibly a little off-centre. No ideas at the moment how to improve
that.

mpd is a networked application — while by default it listens only on
`localhost`, you can configure it to listen on any or all interfaces and be
available over your local network or even the Internet. All of these scripts
rely on your `mpd` client, in this case `ncmpcpp`, having direct access to the
music library and its files, which is probably not going to be the case for a
non-localhost `mpd` server. I can think of various tricky ways to handle this,
but again it's not relevant to my situation at present.
