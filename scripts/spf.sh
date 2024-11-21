#!/bin/bash

# Global associative array to track IPs and where they appear
declare -A ip_tracker

# Function to retrieve SPF records for a given domain
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

    # Extract mechanisms from SPF record
    a_mechanisms=$(echo "$spf" | grep -oP 'a(:\S+)?')
    mx_mechanisms=$(echo "$spf" | grep -oP 'mx(:\S+)?')
    ip4_mechanisms=$(echo "$spf" | grep -oP 'ip4:[^\s]+')
    ip6_mechanisms=$(echo "$spf" | grep -oP 'ip6:[^\s]+')
    includes=$(echo "$spf" | grep -oP 'include:\S+')
    redirect=$(echo "$spf" | grep -oP 'redirect=[^\s]+')

    # Handle 'a' mechanisms (both +a and a)
    if [ -n "$a_mechanisms" ]; then
        for a in $a_mechanisms; do
            # Extract the domain (after `a:` if it exists)
            a_domain="${a#*:}"
            a_domain="${a_domain:-$domain}"  # default to the original domain if no subdomain
            echo -e "${indent}    'a' mechanism found for $a_domain"
            
            # Resolve IPs for the 'a' mechanism
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

    # Handle 'mx' mechanisms (both +mx and mx)
    if [ -n "$mx_mechanisms" ]; then
        for mx in $mx_mechanisms; do
            # Extract the domain (after `mx:` if it exists)
            mx_domain="${mx#*:}"
            mx_domain="${mx_domain:-$domain}"  # default to the original domain if no subdomain
            echo -e "${indent}    'mx' mechanism found for $mx_domain"
            
            # Resolve MX records for the domain
            mx_hosts=$(dig +short MX "$mx_domain")
            if [ -z "$mx_hosts" ]; then
                echo -e "${indent}    No MX records found for $mx_domain"
            else
                echo -e "${indent}    MX hosts for $mx_domain:"
                for mx_host in $mx_hosts; do
                    mx_host_name=$(echo "$mx_host" | awk '{print $2}')
                    echo -e "${indent}        MX Host: $mx_host_name"
                    
                    # Resolve IPs for the MX host
                    mx_ips=$(dig +short "$mx_host_name")
                    if [ -z "$mx_ips" ]; then
                        echo -e "${indent}        No IPs found for $mx_host_name"
                    else
                        for mx_ip in $mx_ips; do
                            echo -e "${indent}        IP: $mx_ip"
                            # Track the IP and its associated domain
                            ip_tracker["$mx_ip"]+="$domain "
                        done
                    fi
                done
            fi
        done
    fi

    # Handle 'ip4:' mechanisms and list IP addresses or CIDR
    if [ -n "$ip4_mechanisms" ]; then
        for ip4 in $ip4_mechanisms; do
            ip4_address="${ip4#*:}"
            echo -e "${indent}    'ip4' mechanism found for $ip4_address"
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
            echo -e "${indent}    'ip6' mechanism found for $ip6_address"
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
