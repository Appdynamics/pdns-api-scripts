#!/usr/bin/env bash

#FIXME: add license header

USAGE="\
delete-pdns-ptr-record.sh [options] <IPv4 address>

Deletes the PTR record with the specified IP address via the PowerDNS REST API.

Option:
    -D                      Delete the PTR record's parent zone, if, and only
                            if it is empty.
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
    DIG

source @SHAREDIR@/pdns-api-script-functions.sh

DELETE_EMPTY_ZONE=false
DEBUG=false
DEBUG_FLAG=
HELP=false
CURL_OUTFILE=

cleanup(){
    if [ -n "$CURL_OUTFILE" ]; then
        rm -f "$CURL_OUTFILE" >/dev/null 2>&1
    fi
}

trap cleanup EXIT

# $1: reverse-zone name to query, i.e. 127.in-addr.arpa.
reverse_zone_is_empty(){
    [[ 0 -eq $($DIG @"$PDNS_API_IP" "$1" AXFR | awk 'BEGIN{n=0}{if($4=="PTR")n++;}END{print n}') ]]
}

input_errors=0
while getopts ":Ddh" flag; do
    case $flag in
        D)
            DELETE_EMPTY_ZONE=true
        ;;
        d)
            CURL_VERBOSE=-v
            DEBUG=true
            DEBUG_FLAG=-d
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

if $HELP; then
    echo "$USAGE"
    exit 0
fi

shift $((OPTIND - 1))

# validate PTR IP address
if ! is_valid_ipv4_address "$1"; then
    >&2 echo "'$1' is not a valid IPv4 Address."
    ((input_errors++))
fi

if [ $input_errors -gt 0 ]; then
    >&2 cat <<USAGE_MSG

$USAGE

Exiting.
USAGE_MSG
    exit $input_errors
fi

HOST=`get_ptr_host_part $1`
ZONE=`get_ptr_zone_part $1`

CURL_OUTFILE="$(mktemp)"

curl $CURL_VERBOSE\
    --request PATCH\
    --header "Content-Type: application/json"\
    --header "X-API-Key: $PDNS_API_KEY"\
    --data @-\
    -w \\n%{http_code}\\n\
    http://$PDNS_API_IP:$PDNS_API_PORT/api/v1/servers/localhost/zones/$ZONE <<PATCH_REQUEST_BODY > "$CURL_OUTFILE"
{
    "rrsets":
        [
            {
                "name": "$HOST",
                "type": "PTR",
                "changetype": "DELETE"
            }
        ],
    "comments": []
}
PATCH_REQUEST_BODY


if [[ $(tail -1 "$CURL_OUTFILE") -eq 200 ]]; then
    if $DELETE_EMPTY_ZONE && reverse_zone_is_empty $ZONE; then
        delete-pdns-zone.sh $ZONE
    fi
else
    # pretty-print the error message JSON
    head -1 "$CURL_OUTFILE" | jq
    exit 1
fi
