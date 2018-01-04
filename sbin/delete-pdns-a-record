#!/bin/bash

# Copyright 2017, AppDynamics LLC and its affiliates
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

USAGE="\
delete-pdns-a-record.sh [options] hostname.zonename.tld.

Deletes the specified, fully qualified A record from PowerDNS.

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
declare PDNS_IP \
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
if ! is_valid_forward_dns_name "$A_RECORD_NAME"; then
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

PTR_FQDN=$(get_host_by_addr $A_RECORD_IP)
if $DELETE_PTR; then
    if [ -n "$PTR_FQDN" ]; then
        if [ "$PTR_FQDN" != "$A_RECORD_NAME" ]; then
            >&2 echo "A record for $A_RECORD_NAME"
            >&2 echo "Does not match PTR record for $A_RECORD_IP"
            >&2 echo "Exiting without changes."
            exit 1
        fi
    else
        >&2 echo "WARNING: Corresponding PTR record for $A_RECORD_NAME"
        >&2 echo "does not exist.  Unable to delete."
        DELETE_PTR=false
    fi
fi

if zone_exists $A_RECORD_NAME; then
    A_RECORD_ZONE=$A_RECORD_NAME
else
    A_RECORD_ZONE=`get_zone_part $A_RECORD_NAME`
fi

CURL_OUTFILE="$(mktemp)"

cat > "$CURL_INFILE" <<PATCH_REQUEST_BODY
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

if $DEBUG; then
    >&2 echo "Patch request body:"
    >&2 jq < "$CURL_INFILE"
fi

curl -s $CURL_VERBOSE\
    --request PATCH\
    --header "Content-Type: application/json"\
    --header "X-API-Key: $PDNS_API_KEY"\
    --data @-\
    -w \\n%{http_code}\\n\
    http://$PDNS_IP:$PDNS_API_PORT/api/v1/servers/localhost/zones/$A_RECORD_ZONE < "$CURL_INFILE" > "$CURL_OUTFILE"

if process_curl_output $? "Failed to Delete A record: $A_RECORD_NAME"; then
    if $DELETE_PTR; then
        delete-pdns-ptr-record.sh $DEBUG_FLAG -D -C $PDNS_CONF $A_RECORD_IP
    fi
fi