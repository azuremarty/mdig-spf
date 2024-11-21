# Function to resolve A or MX records and track their associated IPs
resolve_record() {
    domain=$1
    mechanism=$2
    indent=$3
    
    echo -e "${indent}Resolving $mechanism record for $domain"
    
    # Handle 'a' mechanism (resolve A record)
    if [[ "$mechanism" == "a" || "$mechanism" == "+a" ]]; then
        ips=$(dig +short "$domain")
        if [ -z "$ips" ]; then
            echo -e "${indent}    No IPs found for A record of $domain"
        else
            echo -e "${indent}    IPs for A record of $domain:"
            for ip in $ips; do
                echo -e "${indent}        $ip"
                ip_tracker["$ip"]+="$domain "
            done
        fi
    fi

    # Handle 'mx' mechanism (resolve MX record)
    if [[ "$mechanism" == "mx" || "$mechanism" == "+mx" ]]; then
        mx_records=$(dig +short MX "$domain" | grep -v '^$')
        
        if [ -z "$mx_records" ]; then
            echo -e "${indent}    No MX records found for $domain"
        else
            echo -e "${indent}    MX records for $domain:"
            for mx in $mx_records; do
                # Debugging: Print the raw MX record for troubleshooting
                echo -e "${indent}        Raw MX record: $mx"
                
                # Extract the MX host by removing priority and any trailing period
                mx_host=$(echo $mx | awk '{print $2}' | sed 's/\.$//')

                # Ensure mx_host is not empty and contains a dot (valid domain)
                if [[ -n "$mx_host" && "$mx_host" == *.* ]]; then
                    echo -e "${indent}        MX Host: $mx_host"
                    # Resolve IPs for MX host
                    mx_ips=$(dig +short "$mx_host")
                    if [ -z "$mx_ips" ]; then
                        echo -e "${indent}        No IPs found for MX Host: $mx_host"
                    else
                        for mx_ip in $mx_ips; do
                            echo -e "${indent}            $mx_ip"
                            ip_tracker["$mx_ip"]+="$domain "
                        done
                    fi
                else
                    echo -e "${indent}        Invalid MX Host: $mx_host"
                fi
            done
        fi
    fi
}
