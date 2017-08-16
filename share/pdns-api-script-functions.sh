# FIXME: add license header here

# Shared constants
TTL=86400
TTL_MIN=0
TTL_MAX=2147483647

# 'declare' variables we set with 'eval' below just to keep the IDE happy
declare PDNS_IP \
    PDNS_PORT \
    PDNS_API_PORT \
    PDNS_API_KEY \

declare DEBUG

# Alias dig for sparse output
# include +tcp so that dig fails fast if DNS server is down
DIG="dig +noquestion +nocomments +nocmd +nostats +tcp"

_cleanup(){
    if [ -f "$CURL_INFILE" ]; then
        rm -f "$CURL_INFILE"
    fi

    if [ -f "$CURL_OUTFILE" ]; then
        rm -f "$CURL_OUTFILE"
    fi
}

trap _cleanup EXIT
CURL_INFILE="$(mktemp)"
CURL_OUTFILE="$(mktemp)"


# Sets $PDNS_IP, $PDNS_API_PORT, $PDNS_API_KEY based on the contents a PowerDNS config file
# $1: path to the active PowerDNS config file
read_pdns_config(){
    local API_KEY_CONF
    local CONFIG_ERRORS=false

    # set $PDNS_IP and $PDNS_API_PORT based on the contents of '@ETCDIR@/pdns/pdns.conf'
    if [ -r "$1" ]; then
        eval $(awk -F = '
            /^webserver-address=/{print "PDNS_IP="$2};/^webserver-port=/{print "PDNS_API_PORT="$2};
            /^include-dir=/{printf("API_KEY_CONF=\"%s/api-key.conf\"\n", $2)}
            /^local-port=/{print "PDNS_PORT="$2};
        ' "$1")
        if [ -r "$API_KEY_CONF" ]; then
            # set $PDNS_API_KEY based on the contents of '@ETCDIR@/pdns/pdns.conf.d/api-key.conf'
            eval $(awk -F = '/^api-key=/{print "PDNS_API_KEY="$2"\n"}' "$API_KEY_CONF")
        else
            if [ -f "$1" ]; then
                >&2 echo "Insufficient permissions to read PowerDNS API key file"
                >&2 echo "'$API_KEY_CONF'"
            else
                >&2 echo "PowerDNS API key file '$API_KEY_CONF' does not exist."
            fi
            return 1
        fi
    else
        >&2 echo "PowerDNS configuration file '$1' is not readable."
        return 1
    fi
    if [ -z "$PDNS_IP" ]; then
        >&2 echo "'webserver-address' parameter is missing from '$1'"
        CONFIG_ERRORS=true
    fi
    if [ -z "$PDNS_API_PORT" ]; then
        >&2 echo "'webserver-port' parameter is missing from '$1'"
        CONFIG_ERRORS=true
    fi
    if [ -z "$PDNS_API_KEY" ]; then
        >&2 echo "'api-key' parameter is missing from '$API_KEY_CONF'"
        CONFIG_ERRORS=true
    fi
    if $CONFIG_ERRORS; then
        return 1
    fi
}


# Print an IP address to STDOUT given a DNS server address and a fully-qualified hostname to resolve
# $1: fully-qualified hostname to resolve
get_host_by_name(){
    $DIG +short -p $PDNS_PORT @$PDNS_IP "$1" 2>/dev/null | tail -1
}

# Print a hostname to STDOUT given a DNS server address and an IP address to lookup in reverse
# $1: IP address to lookup in reverse
get_host_by_addr(){
    $DIG +short -p $PDNS_PORT @$PDNS_IP -x "$1" 2>/dev/null
}

# return 0 (true) if given exactly one argument, and $1 is a valid hostname
is_valid_dns_name(){
    [ ${#@} -eq 1 ] && [[ $1 =~ ^([-A-Za-z0-9]{2,}\.)+$ ]] || [[ $1 =~ ^([0-9]{1,3}\.){1,4}in-addr\.arpa\.$ ]]
}

is_valid_ipv4_address(){
    if [ ${#@} -ne 1 ] || ! [[ "$1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi
    local octets
    eval `echo $1 | awk -F . '{print "octets[0]="$1"\noctets[1]="$2"\noctets[2]="$3"\noctets[3]="$4}'`
    i=0
    while [ $i -lt 4 ]; do
        if ! ([ "${octets[$i]}" -ge 0 ] && [ "${octets[$i]}" -le 255 ]); then
            return 1
        fi
        ((i++))
    done
    return 0
}

# Given IP address a.b.c.d, prints c.b.a.in-addr.arpa. to STDOUT
# $1: IP address
get_ptr_zone_part(){
    if is_valid_ipv4_address "$1"; then
        echo $1 | awk -F . '{printf("%d.%d.%d.in-addr.arpa.\n", $3, $2, $1)}'
    else
        return 1
    fi
}

# Given IP address a.b.c.d prints d to STDOUT
# $1: IP address
get_ptr_host_part(){
    if is_valid_ipv4_address "$1"; then
        echo $1 | cut -d . -f 4
    else
        return 1
    fi
}

# Prints the hostname part of a fully-qualified domain name to STDOUT.
# $1: fully-qualified hostname
get_host_part(){
    echo "$1" | cut -d . -f 1
}

get_zone_part(){
    echo "$1" | awk '{first_dot=index($0, "."); print substr($0, first_dot + 1, length($0)-first_dot);}'
}

zone_exists(){
    HTTP_STATUS_CODE=$(curl -s -w \\n%{http_code}\\n --header "X-API-KEY: $PDNS_API_KEY" \
        http://$PDNS_IP:$PDNS_API_PORT/api/v1/servers/localhost/zones/$1 | tail -1)

    if [ $? -ne 0 ]; then
        >&2 echo "Unable to contact PDNS REST API at '$PDNS_IP:$PDNS_API_PORT'"
        >&2 echo "Exiting."
        exit 1
    fi

    case $HTTP_STATUS_CODE in
        200)
            true
        ;;
        422)
            false
        ;;
        *)
            >&2 echo "Unexpected HTTP status code, $HTTP_STATUS_CODE, when checking existence of zone:"
            >&2 echo "$1"
            >&2 echo "Exiting."
            exit 1
        ;;
    esac
}

trailing_dot_msg(){
    >&2 echo "Please note that the trailing dot, ('.'), is required."
}

# If $DEBUG was set, or curl received a non-2xx status code
# Prints the status of the request and the response body on STDERR
# $1: curl exit code
# $2: "Message to print if request failed."
process_curl_output(){
    local ERROR

    if [ "$1" -eq 0 ]; then
        if [[ $(tail -1 "$CURL_OUTFILE") =~ ^2 ]]; then
            ERROR=false
        else
            ERROR=true
        fi

        if $ERROR || $DEBUG; then
            if $ERROR; then
                >&2 echo "$2"
            else
                >&2 echo "Response body:"
            fi
            head -1 "$CURL_OUTFILE" | >&2 jq
            $ERROR && return 1
            return 0
        fi
    else
        >&2 echo "Unable to connect to PowerDNS REST API"
        >&2 echo "'curl' exit code: $1"
        >&2 echo "Exiting."
        exit 1
    fi
}