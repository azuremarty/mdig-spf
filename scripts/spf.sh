#!/bin/bash

# Global associative array to track IPs and where they appear
declare -A ip_tracker

# Function to retrieve SPF records for a given domain, showing them in a tree format
get_spf() {
    domain=$1
    indent=$2
    echo -e "${indent}Fetching SPF record for $domain"
    
    # Fetch the SPF record
    spf=$(dig +short TXT "$domain" | grep -i spf | tr -d '"')
    
    # If no SPF record is found, return
    if [ -z "$spf" ]; then
        echo -e "${indent}No SPF record found for $domain"
        return
    fi

    # Merge split SPF record (e.g., ip6:260 3:10a6::/32 -> ip6:2603:10a6::/32)
    spf=$(echo "$spf" | tr -s ' ' | sed -E 's/(ip6:[0-9]+) ([a-f0-9:]+)/\1\2/g')

    echo -e "${indent}SPF record for $domain: $spf"

    # Extract "include", "a", "+a", "ip4", "ip6", and "redirect" mechanisms from the SPF record
    includes=$(echo "$spf" | grep -oP 'include:\S+')
    a_mechanisms=$(echo "$spf" | grep -oP '\+?a:[^\s]*')
    ip4_mechanisms=$(echo "$spf" | grep -oP 'ip4:[^\s]+')
    ip6_mechanisms=$(echo "$spf" | grep -oP 'ip6:[^\s]+')
    redirect=$(echo "$spf" | grep -oP 'redirect=[^\s]+')

    # Handle 'a:' and '+a:' mechanisms and list associated IP addresses
    if [ -n "$a_mechanisms" ]; then
        for a in $a_mechanisms; do
            a_domain="${a#*:}"
            if [ -z "$a_domain" ]; then
                a_domain="$domain"  # If there's nothing after "a:", use the current domain
            fi
            echo -e "${indent}    'a:' or '+a:' mechanism found for $a_domain"
            
            # Resolve IPs for the 'a:' or '+a:' mechanism
            ips=$(dig +short "$a_domain")
            if [ -z "$ips" ]; then
                echo -e "${indent}    No IPs found for $a_domain"
            else
                echo -e "${indent}    IPs for $a_domain:"
                for ip in $ips; do
                    echo -e "${indent}        $ip"
                    # Track the IP and its associated domain
                    ip_tracker["$ip"]+="$domain "
                done
            fi
        done
    fi

    # Handle 'ip4:' mechanisms and list IP addresses or CIDR
    if [ -n "$ip4_mechanisms" ]; then
        for ip4 in $ip4_mechanisms; do
            ip4_address="${ip4#*:}"
            echo -e "${indent}    'ip4:' mechanism found for $ip4_address"
            if [[ "$ip4_address" =~ / ]]; then
                echo -e "${indent}    CIDR Range: $ip4_address"
            else
                echo -e "${indent}    IP: $ip4_address"
                # Track the IP and its associated domain
                ip_tracker["$ip4_address"]+="$domain "
            fi
        done
    fi

    # Handle 'ip6:' mechanisms and list IP addresses or CIDR
    if [ -n "$ip6_mechanisms" ]; then
        for ip6 in $ip6_mechanisms; do
            ip6_address="${ip6#*:}"
            echo -e "${indent}    'ip6:' mechanism found for $ip6_address"
            if [[ "$ip6_address" =~ / ]]; then
                echo -e "${indent}    CIDR Range: $ip6_address"
            else
                echo -e "${indent}    IP: $ip6_address"
                # Track the IP and its associated domain
                ip_tracker["$ip6_address"]+="$domain "
            fi
        done
    fi

    # Handle 'redirect=' mechanism
    if [ -n "$redirect" ]; then
        redirect_domain="${redirect#redirect=}"
        echo -e "${indent}----------------------------------------------------"
        echo -e "${indent}Following redirect mechanism to: $redirect_domain"
        get_spf "$redirect_domain" "$indent    "
    fi

    # If there are includes, print the separator before fetching the included domain
    if [ -n "$includes" ]; then
        new_indent="${indent}    "
        for include in $includes; do
            included_domain="${include#*:}"
            
            # Print separator line before the "Following include mechanism" message
            echo -e "${indent}----------------------------------------------------"
            echo -e "${indent}Following include mechanism: $included_domain"
            
            # Recursively call get_spf with more indentation
            get_spf "$included_domain" "$new_indent"
        done
    fi
}

# Main execution starts here
if [ -z "$1" ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

domain=$1
get_spf "$domain" ""

# Detect and report duplicate IPs
echo -e "\nDuplicate IPs and their associated SPF hosts:"
echo -e "----------------------------------------------------"
for ip in "${!ip_tracker[@]}"; do
    hosts="${ip_tracker[$ip]}"
    # Check if the IP appears in more than one domain
    if [[ $(echo "$hosts" | wc -w) -gt 1 ]]; then
        echo -e "IP: $ip"
        echo -e "  Found in SPF hosts: $hosts"
    fi
done
