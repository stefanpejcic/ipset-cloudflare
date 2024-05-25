#!/bin/bash

set -e

# Ensure curl and ufw are installed
command -v curl >/dev/null 2>&1 || { echo "curl is required but it's not installed. Aborting." >&2; exit 1; }
command -v ufw >/dev/null 2>&1 || { echo "ufw is required but it's not installed. Aborting." >&2; exit 1; }

# Functions

fetch_cloudflare_ips() {
    ipv4s=$(curl -s https://www.cloudflare.com/ips-v4)
    ipv6s=$(curl -s https://www.cloudflare.com/ips-v6)
    echo -e "$ipv4s\n$ipv6s"
}

allow_cloudflare_ips() {
    ips=$(fetch_cloudflare_ips)
    IFS=$'\n'
    for ip in $ips; do
        ufw allow proto tcp from $ip comment 'Cloudflare IP'
    done
    unset IFS
}

update_ufw_rules() {
    # Fetch existing rules with the 'Cloudflare IP' comment and delete them in reverse order
    rules=$(ufw status numbered | grep 'Cloudflare IP' | awk -F'[][]' '{print $2}' | sort -nr)
    for rule in $rules; do
        ufw --force delete $rule
    done
    allow_cloudflare_ips
}

enable_ufw() {
    ufw reset
    ufw default reject incoming
    ufw limit ssh
    allow_cloudflare_ips
    ufw reload
    ufw enable
}

disable_ufw() {
    ufw reset
    ufw default accept incoming
    ufw unlimit ssh
    update_ufw_rules
    ufw reload
    ufw enable
}

# Main

if [ "$1" == "--enable" ]; then
    enable_ufw
elif [ "$1" == "--disable" ]; then
    disable_ufw
else
    echo "Usage: $0 [--enable|--disable]"
    exit 1
fi
