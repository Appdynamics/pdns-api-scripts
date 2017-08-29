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
delete-pdns-zone.sh [options] zone.name.tld.

Deletes the specified PowerDNS zone.

Options:
    -d                      Enable additional debugging output.
    -C </path/to/pdns.conf> Path to alternate PowerDNS configuration file.
                            Default: @ETCDIR@/pdns/pdns.conf
    -h                      Print this help message, and exit.
"

PDNS_CONF=@ETCDIR@/pdns/pdns.conf

# 'declare' variables we set in @SHAREDIR@/pdns-api-script-functions.sh
# just to keep the IDE happy
declare PDNS_IP \
    PDNS_API_PORT \
    PDNS_API_KEY \
    CURL_OUTFILE

source @SHAREDIR@/pdns-api-script-functions.sh

CURL_VERBOSE=
DEBUG=false
HELP=false

input_errors=0
while getopts ":dC:h" flag; do
    case $flag in
        d)
            CURL_VERBOSE=-v
            DEBUG=true
        ;;
        C)
            PDNS_CONF="$OPTARG"
        ;;
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

if $HELP; then
    echo "$USAGE"
    exit 0
fi

if ! read_pdns_config "$PDNS_CONF"; then
    >&2 echo "Exiting."
    exit 1
fi

shift $((OPTIND-1))

if [ $input_errors -gt 0 ]; then
    >&2 echo "$USAGE"
    exit $input_errors
fi

if is_valid_forward_dns_name "$1" || is_valid_reverse_dns_name "$1"; then
    curl -s $CURL_VERBOSE\
        --request DELETE\
        --header "X-API-Key: $PDNS_API_KEY"\
        -w \\n%{http_code}\\n\
        http://$PDNS_IP:$PDNS_API_PORT/api/v1/servers/localhost/zones/$1 >$CURL_OUTFILE

    if process_curl_output $? "Failed to delete zone $1"; then
        # delete the zone from /etc/resolver/ (ignore errors or missing file)
        rm -f /etc/resolver/$1
    fi
else
    >&2 echo "'$1' is not a correctly"
    >&2 echo "formatted or fully-qualified zone name."
    trailing_dot_msg
    exit 1
fi
