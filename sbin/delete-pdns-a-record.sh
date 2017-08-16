#!/bin/bash

#FIXME: add license header

USAGE="\
delete-pdns-a-record.sh [options] hostname.zonename.tld.

Deletes the specified, fully qualified hostname from PowerDNS.

Options:
    -p                      Deletes complementary PTR record if it exists and
                            matches the forward record.  Warns if PTR record
                            does not exist.  Exits without changes and warns if
                            A record and PTR record do not match.
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

DELETE_PTR=false
DEBUG=false
DEBUG_FLAG=
HELP=false

input_errors=0
while getopts ":pdC:h" flag; do
    case $flag in
        p)
            DELETE_PTR=true
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

A_RECORD_NAME=$1

# validate hostname
if ! is_valid_dns_name "$A_RECORD_NAME"; then
    >&2 echo "'$A_RECORD_NAME' is not a correctly"
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

A_RECORD_IP=$(get_host_by_name $A_RECORD_NAME)

if [ -z "$A_RECORD_IP" ]; then
    >&2 echo "A record '$A_RECORD_NAME' does not exist."
    >&2 echo "Exiting."
    exit 1
fi

ZONE=$(get_zone_part $A_RECORD_NAME)

CURL_OUTFILE="$(mktemp)"

curl -s $CURL_VERBOSE\
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
                "name": "$A_RECORD_NAME",
                "type": "A",
                "changetype": "DELETE"
            }
        ]
}
PATCH_REQUEST_BODY

if process_curl_output $? "Failed to Delete A record: $A_RECORD_NAME"; then
    if $DELETE_PTR; then
        if [[ -n "$(get_host_by_addr $A_RECORD_IP)" ]]; then
            delete-pdns-ptr-record.sh $DEBUG_FLAG -D -C $PDNS_CONF $A_RECORD_IP
        else
            >&2 echo "WARNING: PTR record for $A_RECORD_IP does not exist. Unable to delete."
        fi
    fi
fi