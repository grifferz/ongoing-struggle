+++
title = "I got tired of having to look up how to list all fail2ban bans"
# No date needed because filename or containing directory should be of the
# form YYYY-MM-DD-slug and Zola can work it out from that.
description = """
It's very strange that there is no simple way to look up all the IPs that are banned in all jails of `fail2ban`.
"""

[taxonomies]
# see `docs/tags_in_use.md` for a list of all tags currently in use.
tags = [
    "bash",
    "fail2ban",
]

[extra]
toc_levels = 1
+++

I have loads of different `fail2ban` jails. Every time I want to know if a
given IP address is banned I have to look up how to show the banned IPs for
every jail, when I don't even remember the names of all the jails.

I find it pretty strange that `fail2ban-client` doesn't have a command that
does this. You have to first list off the names of all your jails and then
list all the IPs that each jail has banned.

I got tired of looking up how to do this, so here's a function for my
`.bash_profile` that does it.

{{ toc() }}

## `fail2ban-list-all`

```bash
fail2ban-list-all() {
   local FB

    FB="fail2ban-client"

    # Use sudo only if we're not already root.
    if [ "$(id -u)" -ne 0 ]; then
        FB="sudo fail2ban-client"
    fi

    local jails
    jails=$($FB status \
        | grep "Jail list" \
        | sed -E 's/^.*:\s*//' \
        | tr ',' ' ')

    if [ -z "$jails" ]; then
        printf "No jails found (or fail2ban-client failed to run).\n" >&2
        return 1
    fi

   for jail in $jails; do
        jail=$(printf "%s" "$jail" | xargs)  # trim whitespace

        local ip_list
        ip_list=$($FB status "$jail" \
            | grep "Banned IP list" \
            | sed 's/^ \+`- Banned IP list://')
        ip_list=$(printf "%s" "$ip_list" | xargs)  # trim whitespace

        # Don't bother printing an empty list.
        if [ "$ip_list" != "" ]; then
            printf "=== %s ===\n" "$jail"
            ip_list=$(printf "%s" "$ip_list" | sed 's/ \+/\n\t/g')
            printf "\t%s\n\n" "$ip_list"
        fi
    done
}
```

## Example run

```text
$ fail2ban-list-all
=== apache-crawlers ===
        104.236.18.52
        104.28.243.188
        107.170.19.29
        107.170.27.121
        107.170.57.107
        114.119.131.42
        114.119.137.43
        114.119.140.79
        114.119.141.53
        114.119.145.239
        114.119.145.88
        114.119.153.220
        114.119.158.193
        129.146.237.0
        129.153.213.34
        136.107.210.81
        144.24.3.91
        159.203.98.180
        161.153.27.144
        161.153.76.163
        162.243.185.8
        162.243.6.134
        162.243.91.42
        167.99.236.165
        216.73.217.148
        2a09:bac5:9442:3af::5e:84
        34.106.177.43
        34.125.169.50
        34.125.86.111
        34.129.109.212
        34.142.202.54
        34.176.236.201
        34.187.226.160

=== apache-noscript-1 ===
        103.216.220.78
        103.229.125.91
        104.199.153.253
        104.238.180.63
        104.28.214.116
        107.173.67.180
        110.35.80.116
        118.145.104.105
        136.107.170.125
        136.113.117.51
        138.197.39.208
        139.28.219.70
        150.241.71.157
        157.230.124.251
        172.161.1.105
        178.122.80.45
        185.177.72.12
        185.177.72.17
        185.177.72.23
        185.177.72.30
        185.177.72.38
        185.177.72.54
        185.177.72.56
        185.177.72.70
        188.95.65.43
        198.23.174.202
        20.104.218.184
        20.113.142.140
        20.170.17.213
        20.189.201.100
        20.194.31.226
        20.194.40.105
        20.203.151.213
        20.203.208.53
        20.215.185.25
        20.215.211.30
        20.215.70.187
        20.218.73.95
        20.250.10.77
        20.251.112.224
        20.52.159.242
        20.63.209.210
        20.63.34.22
        20.78.146.33
        204.44.67.106
        207.175.142.27
        207.175.96.142
        209.97.161.116
        209.99.190.174
        213.168.248.72
        213.202.253.4
        213.209.159.154
        23.99.130.35
        2a09:bac1:76a0:780::5e:5c
        31.132.90.3
        31.76.9.4
        34.101.159.112
        34.124.149.77
        34.126.166.246
        34.133.206.166
        34.139.243.120
        34.148.203.95
        34.150.133.136
        34.175.22.142
        34.181.233.84
        34.21.7.252
        34.41.163.97
        34.41.99.32
        34.7.18.131
        34.74.118.2
        34.76.163.71
        34.77.139.215
        34.77.139.215
        34.81.109.45
        34.84.68.153
        35.188.239.191
        35.227.2.213
        35.231.99.1
        35.245.193.139
        38.114.122.234
        4.223.165.84
        4.223.171.122
        4.225.166.176
        4.232.93.83
        40.83.93.253
        43.163.114.113
        45.148.10.125
        45.148.10.238
        45.148.10.62
        45.74.3.199
        47.79.76.108
        51.107.190.246
        51.116.180.165
        52.231.65.196
        67.220.82.2
        68.221.73.131
        74.248.115.87
        74.248.130.103
        74.248.24.61
        78.142.18.40
        80.190.73.75
        82.97.253.89
        85.215.122.94
        94.154.43.31
        35.185.87.75
        158.158.35.55
        35.221.5.154
        136.66.244.162

```

Hmm, could maybe do with some aggregation…
