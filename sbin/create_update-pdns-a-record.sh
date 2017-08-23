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

MANAGE_PTR=false
DEBUG=false
DEBUG_FLAG=
HELP=false

input_errors=0
while getopts ":t:pdC:h" flag; do
    case $flag in
        t)
            if test "$OPTARG" -ge $TTL_MIN >/dev/null 2>&1 && test "$OPTARG" -le $TTL_MAX >/dev/null 2>&1; then
                TTL=$OPTARG
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

if $HELP; then
    echo "$USAGE"
    exit 0
fi

if ! read_pdns_config "$PDNS_CONF"; then
    >&2 echo "Exiting."
    exit 1
fi

shift $((OPTIND-1))

A_RECORD_NAME="$1"
A_RECORD_IP="$2"

# validate hostname
if ! is_valid_forward_dns_name "$A_RECORD_NAME"; then
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

if zone_exists $A_RECORD_NAME; then
    A_RECORD_ZONE=$A_RECORD_NAME
    A_RECORD_NAME="@"
    if $MANAGE_PTR; then
        create_update-pdns-ptr-record.sh -C "$PDNS_CONF" -c $DEBUG_FLAG -t $TTL $A_RECORD_IP $A_RECORD_ZONE
    fi
else
    # if zone doesn't exist, bail.
    A_RECORD_ZONE=`get_zone_part $A_RECORD_NAME`
    if ! zone_exists $A_RECORD_ZONE; then
        >&2 echo "Error: Zone '$A_RECORD_ZONE' does not exist."
        >&2 echo "Exiting."
        exit 1
    fi
    if $MANAGE_PTR; then
        create_update-pdns-ptr-record.sh -C "$PDNS_CONF" -c $DEBUG_FLAG -t $TTL $A_RECORD_IP $A_RECORD_NAME
    fi
fi



cat > "$CURL_INFILE" <<PATCH_REQUEST_BODY
{
    "rrsets":
        [
            {
                "name": "$A_RECORD_NAME",
                "ttl": $TTL,
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
curl -s $CURL_VERBOSE\
        --request PATCH\
        --header "Content-Type: application/json"\
        --header "X-API-Key: $PDNS_API_KEY"\
        -w \\n%{http_code}\\n \
        --data @-\
        http://$PDNS_IP:$PDNS_API_PORT/api/v1/servers/localhost/zones/$A_RECORD_ZONE \
        < "$CURL_INFILE" \
        > "$CURL_OUTFILE"

process_curl_output $? "Create / update A record operation failed:"
