#!/bin/bash

set -e

# Ensure curl and command -v ufw >/dev/null 2>&1 || { echo "ufw is required but it's not installed. Aborting." >&2; exit 1; }
ufw are installed
command -v curl >/dev/null 2>&1 || { echo "curl is required but it's not installed. Aborting." >&2; exit 1; }
command -v ufw >/dev/null 2>&1 || { echo "ufw is required but it's not installed. Aborting." >&2; exit 1; }

# Functions

fetch_cloudflare_ips() {
    ipv4s=$(curl -s https://www.cloudflare.com/ips-v4)
    ipv6s=$(curl -s https://www.cloudflare.com/ips-v6)
    if [[ -z "$ipv4s" || -z "$ipv6s" ]]; then
        echo "Failed to fetch Cloudflare IPs. Aborting." >&2
        exit 1
    fi
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

delete_ufw_rules() {
    # Fetch existing rules with the 'Cloudflare IP' comment and delete them in reverse order
    rules=$(ufw status numbered | grep 'Cloudflare IP' | awk -F'[][]' '{print $2}' | sort -nr)
    for rule in $rules; do
        ufw --force delete $rule
    done
}


create_ipsets() {
    # Create ipsets for IPv4 and IPv6
    sudo ipset create cloudflare_ipv4 hash:net family inet
    sudo ipset create cloudflare_ipv6 hash:net family inet6
}

populate_ipsets() {
    ips=$(fetch_cloudflare_ips)
    IFS=$'\n'
    for ip in $ips; do
        if [[ $ip =~ : ]]; then
            sudo ipset add cloudflare_ipv6 "$ip"
        else
            sudo ipset add cloudflare_ipv4 "$ip"
        fi
    done
    unset IFS
}

update_ufw_rules_with_ipsets() {
    # Clear existing rules
    sudo ufw reset

    # Set default policies
    sudo ufw default reject incoming
    sudo ufw limit ssh

    # Allow traffic from Cloudflare IP sets
    sudo ufw allow from ipset:cloudflare_ipv4 comment 'Cloudflare IPv4'
    sudo ufw allow from ipset:cloudflare_ipv6 comment 'Cloudflare IPv6'

    # Enable UFW
    sudo ufw --force enable
}

enable_ufw_with_ipsets() {
    command -v ipset >/dev/null 2>&1 || { echo "ipset is required but it's not installed. Aborting." >&2; exit 1; }
    echo "Enabling UFW with Cloudflare IP sets..."
    create_ipsets
    populate_ipsets
    update_ufw_rules_with_ipsets
}

disable_ufw_with_ipsets() {
    echo "Removing Cloudflare IP sets..."
    sudo ipset destroy cloudflare_ipv4
    sudo ipset destroy cloudflare_ipv6
    sudo ufw reset
    sudo ufw default accept incoming
    sudo ufw unlimit ssh
    sudo ufw --force enable
}

enable_ufw() {
    echo "Enabling UFW without Cloudflare IP sets..."
    sudo ufw reset
    sudo ufw default reject incoming
    sudo ufw limit ssh
    allow_cloudflare_ips
    sudo ufw --force enable
}

disable_ufw() {
    echo "Disabling UFW without Cloudflare IP sets..."
    sudo ufw reset
    sudo ufw default accept incoming
    sudo ufw unlimit ssh
    delete_ufw_rules
    sudo ufw --force enable
}

# Main

case "$1" in
    --enable-ipset)
        enable_ufw_with_ipsets
        ;;
    --disable-ipset)
        disable_ufw_with_ipsets
        ;;
    --enable)
        enable_ufw
        ;;
    --disable)
        disable_ufw
        ;;
    *)
        echo "Usage: $0 [--enable-ipset|--disable-ipset|--enable|--disable]"
        exit 1
        ;;
esac
