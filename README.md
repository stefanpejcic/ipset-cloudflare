# ipset-cloudflare
Restrict server access to Cloudflare IPs only!

```
                                                             Linux server
                                                   _____________________________
    __________________________________            |     |                       |
   |                                  |           |  F  |                       |
-->| Traffic comming from Cloudflare  |---------->|  I  |        Websites       |
   |__________________________________|           |  R  |                       |
    __________________________________            |  E  |           &           |
   |                                  |           |  W  |                       |
-->|    Direct access to server IP    |----------X|  A  |      User services    |
   |__________________________________|           |  L  |                       |
                                                  |  L  |                       |
                                                  |_____|_______________________| 

```

This script will disable direct access to server IP addresses and only allow access comming through [Cloudflare proxy IPv4 and IPv6 ranges](https://www.cloudflare.com/ips/).

It will update in background daily and add new Cloudflare IP ranges automatically.

## Usage

To use this script on a standalone server run:

```bash
./run.sh --enable-ipset
```

```bash
./run.sh --disable-ipset
```

----

Tu use it on a [OpenPanel](https://openpanel.co) server:

```bash
opencli cloudflare --enable
```

```bash
opencli cloudflare --disable
```
