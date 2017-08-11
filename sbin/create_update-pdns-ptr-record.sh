#!/bin/bash

#FIXME: insert license header

USAGE="\
create_update-pdns-ptr-record.sh [options] <IP address> hostname.domain.tld.

Creates or updates PTR record in PowerDNS for reverse lookups.

Options:
    -t <0-2147483647>       Record time-to-live, (TTL), in caching name
                            servers. (Overrides the zone default TTL.)
    -c                      Create x.y.z.in-addr.arpa. zone, if it does not
                            already exist.
    -d                      Enable additional debugging output.
    -C </path/to/pdns.conf> Path to alternate PowerDNS configuration file.
                            Default: @ETCDIR@/pdns/pdns.conf
    -h                      Print this help message and exit.
"

# 'declare' variables we set in @SHAREDIR@/pdns-api-script-functions.sh
# just to keep the IDE happy
declare PDNS_API_IP \
    PDNS_API_PORT \
    PDNS_API_KEY \
    DIG \
    CURL_INFILE \
    CURL_OUTFILE

source @SHAREDIR@/pdns-api-script-functions.sh

cleanup(){
    if [ -n "$CURL_OUTFILE" ]; then
        rm -f "$CURL_OUTFILE"
    fi
    if [ -n "$CURL_ERRFILE" ]; then
        rm -f "$CURL_ERRFILE"
    fi
}

trap cleanup EXIT

# $TTL, TTL_LINE, TTL_FLAG intentionally left empty.
TTL=
TTL_LINE=
TTL_FLAG=
TTL_MIN=0
TTL_MAX=2147483647

DEBUG=false
DEBUG_FLAG=
CURL_VERBOSE=
CREATE_NONEXISTENT_ZONE=false
HELP=false

PDNS_CONF=@ETCDIR@/pdns/pdns.conf

input_errors=0
while getopts ":t:cdC:h" flag; do
    case $flag in
        t)
            if test "$OPTARG" -ge $TTL_MIN >/dev/null 2>&1 && test "$OPTARG" -le $TTL_MAX >/dev/null 2>&1; then
                # FIXME: PATCH /api/v1/servers/:server_id/zones/:zone_id with changetype=REPLACE may not accept
                # a missing "ttl" field.
                TTL=$OPTARG
                TTL_LINE="\"ttl\": $TTL,"
            else
                >&2 echo "Record TTL must be an integer from $TTL_MIN to $TTL_MAX."
                ((input_errors++))
            fi
        ;;
        c)
            CREATE_NONEXISTENT_ZONE=true
        ;;
        d)
            DEBUG=true
            DEBUG_FLAG=-d
            CURL_VERBOSE=-v
        ;;
        C)
            PDNS_CONF="$OPTARG"
        ;;
        h)
            HELP=true
        ;;
        *)
            >&2 echo "'-$OPTARG' is not a valid option flag."
            ((input_errors++))
        ;;
    esac
done

read_pdns_config "$PDNS_CONF"

shift $((OPTIND - 1))

if is_valid_ipv4_address "$1"; then
    NEW_PTR_IP=$1
else
    >&2 echo "'$1' is not a valid IPv4 address."
    ((input_errors++))
fi

if is_valid_dns_name "$2"; then
    NEW_PTR_HOSTNAME=$2
else
    >&2 echo "'$2' is not a correctly"
    >&2 echo "formatted, fully-qualified hostname."
    trailing_dot_msg
    ((input_errors++))
fi

if [ $input_errors -gt 0 ]; then
    >&2 cat <<USAGE_MSG

$USAGE

Exiting.
USAGE_MSG
    exit $input_errors
fi

OLD_PTR_IP=`get_host_by_name $NEW_PTR_HOSTNAME`
OLD_PTR_HOSTNAME=`get_host_by_addr $OLD_PTR_IP`
OLD_PTR_ZONE=`get_ptr_zone_part $OLD_PTR_IP`
NEW_PTR_ZONE=`get_ptr_zone_part $NEW_PTR_IP`

if ! zone_exists $NEW_PTR_ZONE; then
    if $CREATE_NONEXISTENT_ZONE; then
        bash -x create-pdns-zone.sh -C "$PDNS_CONF" $DEBUG_FLAG $NEW_PTR_ZONE localhost.
    else
        >&2 echo "Inverse zone $NEW_PTR_ZONE does not exist."
        >&2 echo "Exiting without changes."
        exit 1
    fi
fi

if [ "$OLD_PTR_HOSTNAME" == "$NEW_PTR_HOSTNAME" ]; then
    DELETE_EMPTY_ZONE_FLAG=
    if [ "$OLD_PTR_ZONE" != "$NEW_PTR_ZONE" ]; then
        DELETE_EMPTY_ZONE_FLAG=-D
    fi
    delete-pdns-ptr-record.sh -C "$PDNS_CONF" $DELETE_EMPTY_ZONE_FLAG $DEBUG_FLAG $OLD_PTR_IP
fi

NEW_PTR_HOST_PART=`get_ptr_host_part $NEW_PTR_IP`

cat > $CURL_INFILE <<PATCH_REQUEST_BODY
{
    "rrsets":
        [
            {
                "name": "$NEW_PTR_HOST_PART",
                "type": "PTR",
                $TTL_LINE
                "changetype": "REPLACE",
                "records":
                    [
                        {
                            "content": "$NEW_PTR_HOSTNAME",
                            "disabled": false,
                            "set-ptr": false
                        }
                    ]
            }
        ],
    "comments": []
}
PATCH_REQUEST_BODY

if $DEBUG; then
    >&2 echo "Request body:"
    >&2 jq < $CURL_INFILE
fi

curl $CURL_VERBOSE\
    --request PATCH\
    --header "Content-Type: application/json"\
    --header "X-API-Key: $PDNS_API_KEY"\
    --data @-\
    -w \\n%{http_code}\\n\
    http://$PDNS_API_IP:$PDNS_API_PORT/api/v1/servers/localhost/zones/$NEW_PTR_ZONE > "$CURL_OUTFILE" < "$CURL_INFILE"

process_curl_output "Create / update PTR record failed:"