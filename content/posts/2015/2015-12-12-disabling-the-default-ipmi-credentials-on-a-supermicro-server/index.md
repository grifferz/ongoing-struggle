+++
title = "Disabling the default IPMI credentials on a Supermicro server"
description = """
In an earlier post I mentioned that you should disable the default ADMIN /
ADMIN credentials on the Supermicro IPMI controller. Here's how.
"""

[taxonomies]
tags = [
    "bitfolk",
    "hardware",
    "linux",
    "migrated-from-wordpress",
]

[extra]
hide_from_feed = true
+++

In
[an earlier post](http://strugglers.net/~andy/blog/2015/12/11/installing-debian-by-pxe-using-supermicro-ipmi-serial-over-lan/)
I mentioned that you should disable the default ADMIN / ADMIN credentials on
the IPMI controller. Here's how.

{{ toc() }}

### Install `ipmitool`

`ipmitool` is the utility that you will use from the command line of another
machine in order to interact with the IPMI controllers on your servers.

```txt
# apt-get install ipmitool
```

### List the current users

{% admonition_body(type="note", icon="info") %}

This article was written in December 2015. Since then the EU passed
legislation requiring equipment vendors to stop using static default
credentials. Therefore these days, the default user name is still `ADMIN`, but
the password will be set to a random string that is provided on a sticker that
comes with the server's paperwork.

You will therefore still want to change this password and most of the article
is still relevant for doing so. It just won't be quite so urgent, as it won't
be the well known `ADMIN`.

{% end %}

```txt
$ ipmitool -I lanplus -H 192.168.1.22 -U ADMIN -a user list
Password:
ID  Name             Callin  Link Auth  IPMI Msg   Channel Priv Limit
2   ADMIN            false   false      true       ADMINISTRATOR
```

Here you are specifying the IP address of the server's IPMI controller.
`ADMIN` is the IPMI user name you will use to log in, and it's prompting you
for the password which is also `ADMIN` by default.

### Add a new user

You should add a new user with a name other than `ADMIN`.

I suppose it would be safe to just change the password of the existing `ADMIN`
user, but there is no need to have it named that, so you may as well pick a
new name.

```txt
$ ipmitool -I lanplus -H 192.168.1.22 -U ADMIN -a user set name 3 somename
Password:
$ ipmitool -I lanplus -H 192.168.1.22 -U ADMIN -a user set password 3
Password:
Password for user 3:
Password for user 3:
$ ipmitool -I lanplus -H 192.168.1.22 -U ADMIN -a channel setaccess 1 3 link=on ipmi=on callin=on privilege=4
Password:
$ ipmitool -I lanplus -H 192.168.1.22 -U ADMIN -a user enable 3
Password:
```

From this point on you can switch to using the new user instead.

```txt
$ ipmitool -I lanplus -H 192.168.1.22 -U somename -a user list
Password:
ID  Name             Callin  Link Auth  IPMI Msg   Channel Priv Limit
2   ADMIN            false   false      true       ADMINISTRATOR
3   somename         true    true       true       ADMINISTRATOR
```

### Disable `ADMIN` user

Before doing this bit you may wish to check that the new user you added works
for everything you need it to. Those things might include:

- ssh to somename@192.168.1.22
- Log in on web interface at https://192.168.1.22/
- Various `ipmitool` commands like querying power status:

  ```txt
  $ ipmitool -I lanplus -H 192.168.1.22 -U somename -a power status
  Password:
  Chassis power is on
  ```

If all of that is okay then you can disable `ADMIN`:

```txt
$ ipmitool -I lanplus -H 192.168.1.22 -U somename -a user disable 2
Password:
```

If you are paranoid (or this is just the first time you've done this) you
could now check to see that none of the above things now work when you try to
use `ADMIN` / `ADMIN`.

### Specifying the password

I have not done so in these examples but if you get bored of typing the
password every time then you could put it in the `IPMI_PASSWORD` environment
variable and use `-E` instead of `-a` on the `ipmitool` command line.

When setting the `IPMI_PASSWORD` environment variable you probably don't want
it logged in your shell's history file. Depending on which shell you use there
may be different ways to achieve that.

With `bash`, if you have `ignorespace` in the `HISTCONTROL` environment
variable then commands prefixed by one or more spaces won't be logged.
Alternatively you could temporarily disable history logging with:

```txt
$ set +o history
$ sensitive command goes here
$ set -o history # re-enable history logging
```

So anyway…

```txt
$ echo $HISTCONTROL
ignoredups:ignorespace
$     export IPMI_PASSWORD=letmein
$ # ^ note the leading spaces here
$ # to prevent the shell logging it
$ ipmitool -I lanplus -H 192.168.1.22 -U somename -E power status
Chassis Power is on
```
