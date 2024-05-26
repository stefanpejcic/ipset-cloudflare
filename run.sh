#!/bin/bash
################################################################################
# Script Name: run.sh
# Description: Restrict access to Cloudflare proxy IPs only.
# Usage: opencli cloudflare
#        opencli cloudflare --enable
#        opencli cloudflare --disable
# Author: Stefan Pejcic
# Created: 22.05.2024
# Last Modified: 26.05.2024
# Company: openpanel.co
# Copyright (c) openpanel.co
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
################################################################################

set -e

# Ensure curl and command -v ufw >/dev/null 2>&1 || { echo "ufw is required but it's not installed. Aborting." >&2; exit 1; }
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


add_to_cron() {
    line_to_add="$1"
    cron_file="$2"

    if grep -q "$line_to_add" "$cron_file"; then
        echo "Line already exists in $cron_file."
    else
        echo "$line_to_add" >> "$cron_file"
        echo "Line added successfully to $cron_file."
    fi
}


remove_from_cron() {
    line_to_remove="$1"
    cron_file="$2"

    if grep -q "$line_to_remove" "$cron_file"; then
        temp_file=$(mktemp)
        grep -v "$line_to_remove" "$cron_file" > "$temp_file"
        mv "$temp_file" "$cron_file"
        echo "Line removed successfully from $cron_file."
    else
        echo "Line does not exist in $cron_file."
    fi
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

    # delete cron
    add_to_cron "0 0 * * 0 root opencli cloudflare --enable-ipset" "/etc/cron.d/openpanel"
}

enable_ufw_with_ipsets() {
    command -v ipset >/dev/null 2>&1 || { echo "ipset is required but it's not installed. Aborting." >&2; exit 1; }
    echo "Enabling UFW with Cloudflare IP sets..."
    create_ipsets
    populate_ipsets
    update_ufw_rules_with_ipsets
}

destroy_ufw_ipsets() {
    sudo ipset destroy cloudflare_ipv4
    sudo ipset destroy cloudflare_ipv6
}


disable_ufw_with_ipsets() {
    echo "Removing Cloudflare IP sets..."
    destroy_ufw_ipsets
    sudo ufw reset
    sudo ufw default accept incoming
    sudo ufw unlimit ssh
    sudo ufw --force enable
    remove_from_cron "0 0 * * 0 root opencli cloudflare --enable-ipset" "/etc/cron.d/openpanel"
}




enable_ufw() {
    echo "Enabling UFW without Cloudflare IP sets..."
    #sudo ufw reset
    sudo ufw default reject incoming
    sudo ufw limit ssh
    allow_cloudflare_ips
    sudo ufw --force enable
    add_to_cron "0 0 * * 0 root opencli cloudflare --enable" "/etc/cron.d/openpanel"
}

disable_ufw() {
    echo "Disabling UFW without Cloudflare IP sets..."
    #sudo ufw reset
    sudo ufw default allow incoming
    #todo: sudo ufw unlimit ssh
    delete_ufw_rules
    sudo ufw --force enable
    remove_from_cron "0 0 * * 0 root opencli cloudflare --enable" "/etc/cron.d/openpanel"

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
