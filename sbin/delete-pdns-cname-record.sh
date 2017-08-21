#!/bin/bash

# FIXME: add license header

USAGE="\
delete-pdns-cname-record.sh [options] alias-name.domain.tld.

Deletes the specified CNAME record from PowerDNS

Options:
    -d                      Enable additional debugging output.
    -C </path/to/pdns.conf> Path to alternate PowerDNS configuration file.
    -h                      Print this message and exit.
"

# 'declare' variables we set in @SHAREDIR@/pdns-api-script-functions.sh
# just to keep the IDE happy
declare PDNS_IP \
    PDNS_API_PORT \
    PDNS_API_KEY \
    CURL_INFILE \
    CURL_OUTFILE \
    TTL \
    TTL_MIN \
    TTL_MAX


PDNS_CONF=@ETCDIR@/pdns/pdns.conf

source @SHAREDIR@/pdns-api-script-functions.sh

DEBUG=false
DEBUG_FLAG=
HELP=false

input_errors=0
while getopts ":pdC:h" flag; do
    case $flag in
        t)
            if test "$OPTARG" -ge $TTL_MIN >/dev/null 2>&1 && test "$OPTARG" -le $TTL_MAX >/dev/null 2>&1; then
                TTL=$OPTARG
            else
                >&2 echo "Record TTL must be an integer from $TTL_MIN to $TTL_MAX."
                ((input_errors++))
            fi
        ;;
        d)
            CURL_VERBOSE=-v
            DEBUG=true
            DEBUG_FLAG=-d
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

if $HELP; then
    echo "$USAGE"
    exit 0
fi

if ! read_pdns_config "$PDNS_CONF"; then
    >&2 echo "Exiting."
    exit 1
fi

shift $((OPTIND-1))

CNAME="$1"

if ! is_valid_forward_dns_name "$CNAME"; then
    >&2 echo "'$CNAME' is not a correctly"
    >&2 echo "formatted, fully-qualified hostname."
    trailing_dot_msg
    ((input_errors++))
fi

CNAME_ZONE=$(get_zone_part "$CNAME")

if [ $input_errors -gt 0 ]; then
    >&2 cat <<USAGE_MSG

$USAGE

Exiting.
USAGE_MSG
    exit $input_errors
fi

cat > "$CURL_INFILE" <<PATCH_REQUEST_BODY
{
    "rrsets":
        [
            {
                "name": "$CNAME",
                "type": "CNAME",
                "changetype": "DELETE"
            }
        ]
}
PATCH_REQUEST_BODY

if $DEBUG; then
    >&2 echo "Patch request body:"
    >&2 jq < "$CURL_INFILE"
fi

# create/update A record
curl -s $CURL_VERBOSE\
        --request PATCH\
        --header "Content-Type: application/json"\
        --header "X-API-Key: $PDNS_API_KEY"\
        -w \\n%{http_code}\\n \
        --data @-\
        http://$PDNS_IP:$PDNS_API_PORT/api/v1/servers/localhost/zones/$CNAME_ZONE \
        < "$CURL_INFILE" \
        > "$CURL_OUTFILE"

process_curl_output $? "Delete CNAME record operation failed:"