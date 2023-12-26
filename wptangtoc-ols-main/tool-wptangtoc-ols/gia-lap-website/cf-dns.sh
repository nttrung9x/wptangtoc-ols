#!/bin/bash

# AUTHOR: Steve Ward [steve at tech-otaku dot com]
# URL: https://github.com/tech-otaku/cloudflare-dns.git
# README: https://github.com/tech-otaku/cloudflare-dns/blob/main/README.md

# USAGE: ./cf-dns.sh -d DOMAIN -n NAME -t TYPE -c CONTENT -p PRIORITY -l TTL -x PROXIED [-k] [-o]
# EXAMPLE: ./cf-dns.sh -d example.com -t A -n example.com -c 203.0.113.50 -l 1 -x y
#   See the README for more examples

# gia tuan bắt sử dụng python 2 thay vì python 3, vì centos 7 chỉ hỗ trợ python 2
# sửa thêm dòng 288 để phù hợp với wptangtoc ols
# # # # # # # # # # # # # # # # # # # #
# START-UP CHECKS
#
. /etc/wptt/echo-color
# Exit with error if Python 3 is not installed
    if [ ! $(command -v python2) ]; then 
        printf "\nERROR: * * * This script requires Python 2. * * *\n"
        exit 1
    fi

# Exit with error if the Cloudflare credentials file doesn't exist 

# Gia Tuấn xóa xác thực
# Unset all variables
    unset ANSWER APIKEY AUTH_HEADERS AUTO CONTENT DELETE DNS_ID DOMAIN EMAIL KEY NAME OVERRIDE PRIORITY PROXIED RECORD REQUEST RESPONSE TMPFILE TOKEN TTL TYPE ZONE_ID 


# # # # # # # # # # # # # # # # # # # #
# CONSTANTS
#

EMAIL=$(cat ./auth.json | python2 -c "import sys, json; print(json.load(sys.stdin)['cloudflare']['email'])")
KEY=$(cat ./auth.json | python2 -c "import sys, json; print(json.load(sys.stdin)['cloudflare']['key'])")
TOKEN=$(cat ./auth.json | python2 -c "import sys, json; print(json.load(sys.stdin)['cloudflare']['token'])")



# # # # # # # # # # # # # # # # # # # #
# DEFAULTS
#

AUTH_HEADERS=( "Authorization: Bearer $TOKEN" )
#PRIORITY="5"
#PROXIED="true"
#TTL="1"



# # # # # # # # # # # # # # # # # # # #
# FUNCTION DECLARATIONS
#

# Function to execute when the script terminates
    function tidy_up {
        rm -f $TMPFILE
    }

# Ensure the `tidy_up` function is executed every time the script terminates regardless of exit status
    trap tidy_up EXIT

# Function to display usage help
    function usage {
        cat << EOF
                    
    Syntax: 
    ./$(basename $0) -h
    ./$(basename $0) -d DOMAIN -n NAME -t TYPE -c CONTENT -p PRIORITY -l TTL -x PROXIED [-k] [-o] [-A]
    ./$(basename $0) -d DOMAIN -n NAME -t TYPE -c CONTENT -Z [-a] 

    Options:
    -a              Auto mode. Do not prompt for user interaction.
    -A              Force add new DNS record. Prompts to overwrite existing DNS record(s) if omitted.
    -c CONTENT      DNS record content. REQUIRED.
    -d DOMAIN       The domain name. REQUIRED.
    -h              This help message.
    -k              Use legacy API key for authentication. API token is used if omitted.
    -l TTL          Time to live for DNS record. Must be an integer >= 1. REQUIRED.
    -n NAME         DNS record name. REQUIRED.
    -o              Override use of NAME.DOMAIN to reference applicable DNS record.
    -p PRIORITY     The priority value for an MX type DNS record. Must be an integer >= 0. REQUIRED for MX type record.
    -t TYPE         DNS record type. Must be one of A, AAAA, CNAME, MX or TXT. REQUIRED.       
    -x PROXIED      Should the DNS record be proxied? Must be one of y, Y, n or N. REQUIRED.
    -Z DELETE       Delete a given DNS record.

    Example: ./$(basename $0) -d example.com -t A -n example.com -c 203.0.113.50 -l 1 -x y
    Example: ./$(basename $0) -d example.com -t A -n example.com -c 203.0.113.50 -Z -a

    See https://github.com/tech-otaku/cloudflare-dns/blob/main/README.md for more examples.
    
EOF
    }



# # # # # # # # # # # # # # # # # # # #
# COMMAND-LINE OPTIONS
#

# Exit with error if no command line options given
    if [[ ! $@ =~ ^\-.+ ]]; then
        printf "\nERROR: * * * No options given. * * *\n"
        usage
        exit 1
    fi

# Prevent an option that expects an argument from taking the next option as an argument if its own argument is omitted. i.e. -d -n www 
    while getopts ':aAc:d:hkl:n:op:t:x:Z' opt; do
        if [[ $OPTARG =~ ^\-.? ]]; then
            printf "\nERROR: * * * '%s' is not valid argument for option '-%s'\n" $OPTARG $opt
            usage
            exit 1
        fi
    done

# Reset OPTIND so getopts can be called a second time
    OPTIND=1        

# Process command line options
    while getopts ':aAc:d:hkl:n:op:t:x:Z' opt; do
        case $opt in
            a)
                # This variable is only ever tested to confirm if it's set (non-zero length string) or not (zero length string). Its actual value is of no significance. 
                AUTO=true
                ;;
            A)
                # This variable is only ever tested to confirm if it's set (non-zero length string) or not (zero length string). Its actual value is of no significance. 
                ADD=true
                ;;
            c) 
                CONTENT=$OPTARG 
                ;;
            d) 
                DOMAIN=$OPTARG 
                ;;
            h)
                usage
                exit 0
                ;;
            k)
                # This variable is only ever tested to confirm if it's set (non-zero length string) or not (zero length string). Its actual value is of no significance.
                APIKEY=true
                ;;
            l) 
                TTL=$OPTARG  
                ;;
            n) 
                NAME=$OPTARG  
                ;;
            o)
                # This variable is only ever tested to confirm if it's set (non-zero length string) or not (zero length string). Its actual value is of no significance. 
                OVERRIDE=true
                ;;
            p) 
                PRIORITY=$OPTARG  
                ;;
            t) 
                TYPE=$(echo $OPTARG | tr '[:lower:]' '[:upper:]')  
                ;;
            x) 
                PROXIED=$OPTARG  
                ;;
            Z)
                # This variable is only ever tested to confirm if it's set (non-zero length string) or not (zero length string). Its actual value is of no significance. 
                DELETE=true
                ;;
            :) 
                printf "\nERROR: * * * Argument missing from '-%s' option * * *\n" $OPTARG
                usage
                exit 1
                ;;
            ?) 
                printf "\nERROR: * * * Invalid option: '-%s' * * *\n" $OPTARG
                usage
                exit 1
                ;;
        esac
    done



# # # # # # # # # # # # # # # # # # # #
# USAGE CHECKS
#

# DOMAIN is missing
    if [ -z "$DOMAIN" ] || [[ "$DOMAIN" == -* ]]; then
        printf "\nERROR: * * * No domain was specified. * * *\n"
        usage
        exit 1
    fi

# TYPE is missing or not handled by this script
    if [[ ! $TYPE =~ ^(A|AAAA|CNAME|MX|TXT)$ ]]; then
        printf "\nERROR: * * * DNS record type missing or invalid. * * *\n"
        usage
        exit 1
    fi

# NAME is missing
    if [ -z "$NAME" ] || [[ "$NAME" == -* ]]; then
        printf "\nERROR: * * * No DNS record name was specified. * * *\n"
        usage
        exit 1
    fi

# CONTENT is missing
    if [ -z "$CONTENT" ] || [[ "$CONTENT" == -* ]]; then
        printf "\nERROR: * * * No DNS record content was specified. * * *\n"
        usage
        exit 1
    fi

# Only check PROXIED, TTL and PRIORITY if the DNS record is NOT being deleted

    if [ -z "$DELETE" ]; then

    # PROXIED (non-MX or non-TXT records only) is missing or invalid. Must be specified and be one of y, Y, n, or N
        if [[ ! $TYPE =~ ^(MX|TXT)$ ]]; then 
            if [[ ! $PROXIED =~ ^([yY]|[nN]){1}$ ]]; then
                printf "\nERROR: * * * DNS record proxy status missing or invalid. * * *\n"
                usage
                exit 1
            else
                PROXIED=$( [[ $PROXIED =~ ^(y|Y)$ ]] && echo "true" || echo "false" )
            fi
        fi

    # TTL is missing or invalid. Must be specified and be an integer >= 1 
        if ( [ -z $TTL ] || [[ ! $TTL =~ ^[0-9]*$ ]] || [ ! $TTL -ge 1 ] ); then
            printf "\nERROR: * * * DNS record TTL missing or invalid. * * *\n"
            usage
            exit 1
        fi

    # PRIORITY (MX records only) is missing or invalid. Must be specified and be an integer >= 0 
        if [ $TYPE == "MX" ] && ( [ -z $PRIORITY ] || [[ ! $PRIORITY =~ ^[0-9]*$ ]] || [ ! $PRIORITY -ge 0 ] ); then
            printf "\nERROR: * * * DNS record priority missing or invalid. * * *\n"
            usage
            exit 1
        fi

    fi



# # # # # # # # # # # # # # # # # # # #
# OVERRIDES
#

# Override 'Proxy status'. Only check if the DNS record is NOT being deleted
    if [ -z "$DELETE" ]; then   
        if [ $TTL != "1" ] && [[ $PROXIED != "false" ]]; then
            # A TTL other than "1" can only be set if the DNS record's 'Proxy status' is 'DNS only'  
            PROXIED="false"
        fi
    fi 

# Use legacy API key to authenticate instead of API token
    if [ ! -z "$APIKEY" ]; then 
        AUTH_HEADERS=( "X-Auth-Email: $EMAIL" "X-Auth-Key: $KEY" )
    fi  

# Append domain name to supplied DNS record name. Ensures that all DNS records are managed using their correct naming convention: 'www.example.com' as opposed to 'www' 
#    if [ -z "$OVERRIDE" ]; then                                    # Only if '-o' otion given
        if [ "$NAME" != "$DOMAIN" ]; then
            NAME=$NAME.$DOMAIN
        fi
#    fi



# # # # # # # # # # # # # # # # # # # #
# ADD | UPDATE | DELETE DNS RECORDS
#

# Get the domain's zone ID
    printf "\nAttempting to get zone ID for domain '%s'\n" $DOMAIN
    ZONE_ID=$(
        curl -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
        "${AUTH_HEADERS[@]/#/-H}" \
        -H "Content-Type: application/json" \
        | python2 -c "import sys,json;data=json.loads(sys.stdin.read()); print(data['result'][0]['id'] if data['result'] else '')"
    ) 

    if [ -z "$ZONE_ID" ]; then
		_runloi "Cấu hình domain giả lập ${subdomain_ten_mien}.${domain_phuc_vu}"
		echoDo "Không xác định được zone ID"
        printf "\nABORTING: * * * The domain '%s' doesn't exist on Cloudflare * * *\n" "$DOMAIN"
		echo "Vui lòng thử lại sau"
		exit 1
    else
        printf ">>> %s\n" "$ZONE_ID"
    fi
    
# Get the DNS record's ID based on type, name and content
    printf "\nAttempting to get ID for DNS '%s' record named '%s' whose content is '%s'\n" "$TYPE" "$NAME" "$CONTENT"
    DNS_ID=$(
        curl -G "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" --data-urlencode "type=$TYPE" --data-urlencode "name=$NAME" --data-urlencode "content=$CONTENT" \
        "${AUTH_HEADERS[@]/#/-H}" \
        -H "Content-Type: application/json" \
        | python2 -c "import sys,json;data=json.loads(sys.stdin.read()); print(data['result'][0]['id'] if data['result'] else '')"
    )

    if [ -z "$DNS_ID" ]; then
        printf ">>> %s\n" "No record found (1)"
    else
        printf ">>> %s\n" "$DNS_ID"
    fi

# Add a new DNS record or update an existing one.
    if [ -z "$DELETE" ]; then

    # If no DNS record was found matching type, name and content look for all DNS records matching only type and name
        if [ -z "$DNS_ID" ]; then

            TMPFILE=$(mktemp)

            printf "\nAttempting to get all DNS records whose type is '%s' named '%s'\n" "$TYPE" "$NAME"
            curl -G "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" --data-urlencode "type=$TYPE" --data-urlencode "name=$NAME" \
            "${AUTH_HEADERS[@]/#/-H}" \
            | python -c $'import sys,json\ndata=json.loads(sys.stdin.read())\nif data["success"]:\n\tfor dict in data["result"]:print(dict["id"] + "," + dict["type"] + "," + dict["name"] + "," + dict["content"])\nelse:print("ERROR(" + str(data["errors"][0]["code"]) + "): " + data["errors"][0]["message"])' > $TMPFILE

            if [ $(wc -l < $TMPFILE) -gt 0 ]; then
                printf "\nFound %s existing DNS record(s) whose type is '%s' named '%s'\n" $(wc -l < $TMPFILE) "$TYPE" "$NAME"
                i=0
                while read record; do
                    i=$((i+1))
                    printf '[%s] ID:%s, TYPE:%s, NAME:%s, CONTENT:%s\n' $i "$(printf '%s' "$record" | cut -d ',' -f1)" "$(printf '%s' "$record" | cut -d ',' -f2)" "$(printf '%s' "$record" | cut -d ',' -f3)" "$(printf '%s' "$record" | cut -d ',' -f4)"
                done < $TMPFILE
                echo "[A] Add New DNS Record"
                echo -e "[Q] Quit\n"
            
                while true; do
                    read -p "Type $(for((x=1;x<=$i;++x)); do printf "'%s', " $x; done | rev | cut -c3- | sed 's/ ,/ ro /' | rev) to update an existing record, 'A' to add a new record or 'Q' to quit without changes and then press enter: " ANSWER
                    case $ANSWER in
                        [1-$i]) 
                            DNS_ID=$(sed -n $ANSWER'p' < $TMPFILE | cut -d ',' -f1 | cut -d ':' -f2); 
                            break;;
                        [aA])
                            unset DNS_ID; 
                            break;;
                        [qQ]) 
                            exit
                            ;;
                        *) 
    #                        echo "Please enter a valid option."
                            ;;
                    esac
                done

            else

                printf ">>> %s\n" "No record(s) found (2)"

            fi

        fi

        if [ -z "$DNS_ID" ]; then
        # DNS record doesn't exist. Create a new one.
            REQUEST=("POST https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/")
            printf "\nAdding new DNS '%s' record named '%s'\n" $TYPE $NAME
        else
        # DNS record already exists. Update the existing record.
            REQUEST=("PUT https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$DNS_ID")
            printf "\nUpdating existing DNS '%s' record named '%s'\n" $TYPE $NAME
        fi

        if [ $TYPE == "A" ] || [  $TYPE == "AAAA" ] || [ $TYPE == "CNAME" ]; then
            curl ${REQUEST[@]/#/-X} \
            "${AUTH_HEADERS[@]/#/-H}" \
            -H "Content-Type: application/json" \
            --data '{"type":"'"$TYPE"'","name":"'"$NAME"'","content":"'"$CONTENT"'","proxied":'"$PROXIED"',"ttl":'"$TTL"'}' \
            | python2 -m json.tool --sort-keys
        elif [ $TYPE == "MX" ]; then
            curl ${REQUEST[@]/#/-X} \
            "${AUTH_HEADERS[@]/#/-H}" \
            -H "Content-Type: application/json" \
            --data '{"type":"'"$TYPE"'","name":"'"$NAME"'","content":"'"$CONTENT"'","priority":'"$PRIORITY"',"ttl":'"$TTL"'}' \
            | python2 -m json.tool --sort-keys
        else
            curl ${REQUEST[@]/#/-X} \
            "${AUTH_HEADERS[@]/#/-H}" \
            -H "Content-Type: application/json" \
            --data '{"type":"'"$TYPE"'","name":"'"$NAME"'","content":"'"$CONTENT"'","ttl":'"$TTL"'}' \
            | python2 -m json.tool --sort-keys
        fi 

# Delete an existing DNS record
    else

        RECORD=$(printf "DNS '%s' record named '%s' whose content is '%s'" "$TYPE" "$NAME" "$CONTENT")

        if [ -z "$DNS_ID" ]; then
            printf "\nWARNING: * * * No $RECORD exists * * *\n" 
        else
            if [ -z $AUTO ]; then
               read -r -p "$(echo -e '\n'Delete the $RECORD [Y/n]?) " RESPONSE
            else
                RESPONSE=Y
            fi
            
            if [[ "$RESPONSE" =~ ^([yY][eE][sS]|[yY])$ ]]; then

                printf "\nDeleteing the $RECORD\n"      

                curl -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$DNS_ID" \
                "${AUTH_HEADERS[@]/#/-H}" \
                -H "Content-Type: application/json" \
                | python2 -m json.tool --sort-keys

            else
                printf "\nThe $RECORD has NOT been deleted.\n"
            fi
        fi
    fi
