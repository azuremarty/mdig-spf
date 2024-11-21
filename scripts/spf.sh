#!/bin/bash

# Global associative array to track IPs and where they appear
declare -A ip_tracker

# Function to resolve A and MX records for the domain
resolve_a_mx_mechanisms() {
    domain=$1
    indent=$2

    # Resolve 'a' and '+a' mechanisms
    if [[ "$spf" =~ (^|\s)(\+)?a(\s|$) ]]; then
        echo -e "${indent}'a' mechanism found for $domain"
        ips=$(dig +short "$domain" A)
        if [ -z "$ips" ]; then
            echo -e "${indent}    No IPs found for $domain"
        else
            echo -e "${indent}    IPs for $domain:"
            for ip in $ips; do
                echo -e "${indent}        $ip"
                ip_tracker["$ip"]+="$domain "
            done
        fi
    fi

    # Resolve 'mx' and '+mx' mechanisms
    if [[ "$spf" =~ (^|\s)(\+)?mx(\s|$) ]]; then
        echo -e "${indent}'mx' mechanism found for $domain"
        mx_hosts=$(dig +short "$domain" MX | awk '{print $2}')
        if [ -z "$mx_hosts" ]; then
            echo -e "${indent}    No MX records found for $domain"
        else
            echo -e "${indent}    MX hosts for $domain:"
            for mx in $mx_hosts; do
                echo -e "${indent}        $mx"
                mx_ips=$(dig +short "$mx" A)
                if [ -z "$mx_ips" ]; then
                    echo -e "${indent}        No IPs found for $mx"
                else
                    echo -e "${indent}        IPs for $mx:"
                    for ip in $mx_ips; do
                        echo -e "${indent}            $ip"
                        ip_tracker["$ip"]+="$domain "
                    done
                fi
            done
        fi
    fi
}

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

    echo -e "${indent}SPF record for $domain: $spf"

    # Handle 'ip4:' mechanisms and list IP addresses or CIDR
    ip4_mechanisms=$(echo "$spf" | grep -oP 'ip4:[^\s]+')
    if [ -n "$ip4_mechanisms" ]; then
        for ip4 in $ip4_mechanisms; do
            ip4_address="${ip4#*:}"
            echo -e "${indent}    'ip4:' mechanism found for $ip4_address"
            if [[ "$ip4_address" =~ / ]]; then
                echo -e "${indent}    CIDR Range: $ip4_address"
            else
                echo -e "${indent}    IP: $ip4_address"
                ip_tracker["$ip4_address"]+="$domain "
            fi
        done
    fi

    # Handle 'ip6:' mechanisms and list IP addresses or CIDR
    ip6_mechanisms=$(echo "$spf" | grep -oP 'ip6:[^\s]+')
    if [ -n "$ip6_mechanisms" ]; then
        for ip6 in $ip6_mechanisms; do
            ip6_address="${ip6#*:}"
            echo -e "${indent}    'ip6:' mechanism found for $ip6_address"
            if [[ "$ip6_address" =~ / ]]; then
                echo -e "${indent}    CIDR Range: $ip6_address"
            else
                echo -e "${indent}    IP: $ip6_address"
                ip_tracker["$ip6_address"]+="$domain "
            fi
        done
    fi

    # Call resolver for +a, a, +mx, and mx
    resolve_a_mx_mechanisms "$domain" "$indent"

    # Extract and handle 'include' mechanisms
    includes=$(echo "$spf" | grep -oP 'include:\S+')
    if [ -n "$includes" ]; then
        new_indent="${indent}    "
        for include in $includes; do
            included_domain="${include#*:}"
            echo -e "${indent}----------------------------------------------------"
            echo -e "${indent}Following include mechanism: $included_domain"
            get_spf "$included_domain" "$new_indent"
        done
    fi

    # Handle 'redirect=' mechanism
    redirect=$(echo "$spf" | grep -oP 'redirect=[^\s]+')
    if [ -n "$redirect" ]; then
        redirect_domain="${redirect#redirect=}"
        echo -e "${indent}----------------------------------------------------"
        echo -e "${indent}Following redirect mechanism to: $redirect_domain"
        get_spf "$redirect_domain" "$indent    "
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
    if [[ $(echo "$hosts" | wc -w) -gt 1 ]]; then
        echo -e "IP: $ip"
        echo -e "  Found in SPF hosts: $hosts"
    fi
done
