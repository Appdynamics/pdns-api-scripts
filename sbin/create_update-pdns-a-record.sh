#!/bin/bash

# FIXME: add license header

# TODO: add support for multiple addresses per A record (incompatible with -p flag)
USAGE="\
create_update-pdns-a-record.sh [options] hostname.zonename.tld. <IP Address>

Creates or updates a DNS 'A' record if PowerDNS hosts the containing zone.

Options:
    -t <0-2147483647>       Record time-to-live, (TTL), in caching name
                            servers. (Overrides the zone default TTL.)
    -p                      Create or update a complementary PTR record.
                            (Creates the necessary x.y.z.in-addr.arpa. zone,
                            if it does not already exist. A-record TTL will
                            pass through to the PTR record, if specified. If
                            not, PTR record will use inverse zone's default
                            TTL.)
    -d                      Enable additional debugging output.
    -C </path/to/pdns.conf> Path to alternate PowerDNS configuration file.
                            Default: @ETCDIR@/pdns/pdns.conf
    -h                      Print this message and exit.
"

# 'declare' variables we set in @SHAREDIR@/pdns-api-script-functions.sh
# just to keep the IDE happy
declare PDNS_API_IP \
    PDNS_API_PORT \
    PDNS_API_KEY \
    CURL_INFILE \
    CURL_OUTFILE

PDNS_CONF=@ETCDIR@/pdns/pdns.conf

source @SHAREDIR@/pdns-api-script-functions.sh

MANAGE_PTR=false
DEBUG=false
DEBUG_FLAG=
HELP=false


# $TTL, TTL_LINE, TTL_FLAG intentionally left empty.
TTL=
TTL_LINE=
TTL_FLAG=
TTL_MIN=0
TTL_MAX=2147483647

input_errors=0
while getopts ":t:pdC:h" flag; do
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
        p)
            MANAGE_PTR=true
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

read_pdns_config "$PDNS_CONF"

if $HELP; then
    echo "$USAGE"
    exit 0
fi

shift $((OPTIND-1))

A_RECORD_NAME="$1"
A_RECORD_IP="$2"

# validate hostname
if ! is_valid_dns_name "$A_RECORD_NAME"; then
    >&2 echo "'$A_RECORD_NAME' is not a correctly"
    >&2 echo "formatted, fully-qualified hostname."
    trailing_dot_msg
    ((input_errors++))
fi

# validate IP address
if ! is_valid_ipv4_address "$A_RECORD_IP"; then
    >&2 echo "'$A_RECORD_IP' is not a correctly formatted IPv4 address."
    ((input_errors++))
fi

if [ $input_errors -gt 0 ]; then
    >&2 cat <<USAGE_MSG

$USAGE

Exiting.
USAGE_MSG
    exit $input_errors
fi

# if zone doesn't exist, bail.
A_RECORD_ZONE=`get_zone_part $A_RECORD_NAME`
if ! zone_exists $A_RECORD_ZONE; then
    >&2 echo "Error: Zone '$A_RECORD_ZONE' does not exist."
    >&2 echo "Exiting."
    exit 1
fi

if $MANAGE_PTR; then
    # create/update PTR record
    if [ -n "$TTL" ]; then
        TTL_FLAG="-t $TTL"
    fi
    create_update-pdns-ptr-record.sh -c $DEBUG_FLAG $TTL_FLAG $A_RECORD_IP $A_RECORD_NAME
fi

cat > "$CURL_INFILE" <<PATCH_REQUEST_BODY
{
    "rrsets":
        [
            {
                "name": "$A_RECORD_NAME",
                $TTL_LINE
                "type": "A",
                "changetype": "REPLACE",
                "records":
                    [
                        {
                            "content": "$A_RECORD_IP",
                            "disabled": false,
                            "set-ptr": false
                        }
                    ],
                "comments": []
            }
        ]
}
PATCH_REQUEST_BODY

if $DEBUG; then
    >&2 echo "Patch request body:"
    >&2 jq < "$CURL_INFILE"
fi

# create/update A record
curl $CURL_VERBOSE\
        --request PATCH\
        --header "Content-Type: application/json"\
        --header "X-API-Key: $PDNS_API_KEY"\
        -w \\n%{http_code}\\n \
        --data @-\
        http://$PDNS_API_IP:$PDNS_API_PORT/api/v1/servers/localhost/zones/$A_RECORD_ZONE \
        < "$CURL_INFILE" \
        > "$CURL_OUTFILE"

# TODO: report on non-zero curl exit status, (connection failures), and exit
process_curl_output "Create / update A record operation failed:"
