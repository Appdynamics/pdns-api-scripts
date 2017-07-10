#!/bin/bash

# FIXME: add license header

USAGE="\
delete-pdns-zone.sh [options] zone.name.tld.

Deletes the specified PowerDNS zone.

Options:
    -h  Print this help message, and exit.
"

# 'declare' variables we set in @SHAREDIR@/pdns-api-script-functions.sh
# just to keep the IDE happy
declare PDNS_API_IP \
    PDNS_API_PORT \
    PDNS_API_KEY

source @SHAREDIR@/pdns-api-script-functions.sh

input_errors=0
while getopts ":h" flag; do
    case flag in
        h)
            echo "$USAGE"
            exit 0
        ;;
        *)
            >&2 echo "'-$OPTARG' is not a supported option."
            ((input_errors++))
        ;;
    esac
done

shift $((OPTIND-1))

if is_valid_dns_name "$1"; then
    curl $CURL_VERBOSE\
        --request DELETE\
        --header "X-API-Key: $PDNS_API_KEY"\
        http://$PDNS_API_IP:$PDNS_API_PORT/api/v1/servers/localhost/zones/$1
    exit $?
else
    >&2 echo "'$1' is not a correctly"
    >&2 echo "formatted or fully-qualified zone name."
    trailing_dot_msg
    ((input_errors++))
fi

if [ $input_errors -gt 0 ]; then
    >&2 echo "$USAGE"
    exit $input_errors
fi