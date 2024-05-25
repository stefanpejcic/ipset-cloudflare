#!/bin/bash

ufw reset
ufw default reject incoming

# Fetch Cloudflare IPs
ipv4s=$(curl -s https://www.cloudflare.com/ips-v4)
ipv6s=$(curl -s https://www.cloudflare.com/ips-v6)
ips=$(echo -e "$ipv4s\n$ipv6s")

IFS=$'\n'
for ip in $ips; do
     ufw allow proto tcp from $ip comment 'Cloudflare IP'
done
unset IFS

ufw limit ssh
ufw reload
ufw enable

