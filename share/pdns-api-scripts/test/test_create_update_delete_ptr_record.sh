#@IgnoreInspection BashAddShebang

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

source "@SHAREDIR@/pdns-api-script-functions.sh"

testCreateUpdatePtrRecord(){
    local PTR_IP=$(_random_ipv4_octet).6.$(_random_ipv4_octet).$(_random_ipv4_octet)
    local PTR_HOSTNAME=$(_random_alphanumeric_chars 8).$(_random_alphanumeric_chars 3).tld.
    local PTR_ZONE_PART=$(get_ptr_zone_part $PTR_IP)
    local PTR_HOST_PART=$(get_ptr_host_part $PTR_IP)
    local TTL=86401
    local DEBUG_FLAG

    if [ "$ENABLE_DEBUG" == "true" ]; then
        DEBUG_FLAG=-d
    fi

    # attempt to create ptr record exercising all flags except -c
    local CREATE_OUT=$( 2>&1 create_update-pdns-ptr-record.sh -C "$PDNS_CONF_DIR/pdns.conf" $DEBUG_FLAG -t $TTL $PTR_IP \
        $PTR_HOSTNAME | head -1)

    # assert that it failed
    assertEquals "Inverse zone $PTR_ZONE_PART does not exist." "$CREATE_OUT"

    # create ptr record with -c flag
    create_update-pdns-ptr-record.sh -C "$PDNS_CONF_DIR/pdns.conf" $DEBUG_FLAG -c -t $TTL $PTR_IP $PTR_HOSTNAME

    # assert that it succeeded
    local DIG_PTR_HOSTNAME
    local DIG_TTL
    eval $($TEST_DIG -x $PTR_IP | awk '
        /[\t\s]PTR[\t\s]/{
            print "DIG_TTL="$2;
            print "DIG_PTR_HOSTNAME="$5;
        }
    ')
    assertEquals "PTR TTL" "$TTL" "$DIG_TTL"
    assertEquals "PTR hostname" "$PTR_HOSTNAME" "$DIG_PTR_HOSTNAME"

    # update ptr record
    PTR_HOSTNAME=$(_random_alphanumeric_chars 8).$(_random_alphanumeric_chars 3).tld.
    TTL=86399
    create_update-pdns-ptr-record.sh -C "$PDNS_CONF_DIR/pdns.conf" $DEBUG_FLAG -t $TTL $PTR_IP $PTR_HOSTNAME

    _wait_for_cache_expiry

    # assert that it updated
    eval $($TEST_DIG -x $PTR_IP | awk '
        /[\t\s]PTR[\t\s]/{
            print "DIG_TTL="$2;
            print "DIG_PTR_HOSTNAME="$5;
        }
    ')

    assertEquals "PTR TTL after update" "$TTL" "$DIG_TTL"
    assertEquals "PTR hostname after update" "$PTR_HOSTNAME" "$DIG_PTR_HOSTNAME"

    delete-pdns-zone.sh -C "$PDNS_CONF_DIR/pdns.conf" $DEBUG_FLAG $PTR_ZONE_PART
}

testDeletePtrRecord(){
    local PTR_IP=$(_random_ipv4_octet).$(_random_ipv4_octet).$(_random_ipv4_octet).$(_random_ipv4_octet)
    local PTR_HOSTNAME=$(_random_alphanumeric_chars 8).$(_random_alphanumeric_chars 3).tld.
    local PTR_ZONE_PART=$(get_ptr_zone_part $PTR_IP)
    local PTR_HOST_PART=$(get_ptr_host_part $PTR_IP)
    local TTL=86401
    local DEBUG_FLAG

    if [ "$ENABLE_DEBUG" == "true" ]; then
        DEBUG_FLAG=-d
    fi

    # create record
    create_update-pdns-ptr-record.sh -C "$PDNS_CONF_DIR/pdns.conf" $DEBUG_FLAG -c -t $TTL $PTR_IP $PTR_HOSTNAME

    # delete ptr record
    delete-pdns-ptr-record.sh -C "$PDNS_CONF_DIR/pdns.conf" "$PTR_IP"

    # assert that $TEST_DIG -x $PTR_IP returns the SOA and only the SOA (PTR is gone, zone is still there)
    local DIG_ZONE_NAME
    local DIG_LINE_COUNT
    eval $($TEST_DIG -x $PTR_IP | awk '
        /[\t\s]SOA[\t\s]/{print "DIG_ZONE_NAME="$1;};
        END{print "DIG_LINE_COUNT="NR;};
    ')
    assertEquals "Inverse zone missing after deleting PTR record:" "$PTR_ZONE_PART" "$DIG_ZONE_NAME"
    assertEquals "Wrong number of records returned by dig after deleting PTR record." "1" "$DIG_LINE_COUNT"

    # mid-test cleanup
    delete-pdns-zone.sh -C "$PDNS_CONF_DIR/pdns.conf" $DEBUG_FLAG $PTR_ZONE_PART

    # create 2 ptr records in the same zone
    local PTR_SUFFIX=$(_random_ipv4_octet).$(_random_ipv4_octet).$(_random_ipv4_octet)
    PTR_IP=$(_random_ipv4_octet).$PTR_SUFFIX
    local PTR_IP2=$(_random_ipv4_octet).$PTR_SUFFIX
    PTR_ZONE_PART=$(get_ptr_zone_part $PTR_IP)
    create_update-pdns-ptr-record.sh -C "$PDNS_CONF_DIR/pdns.conf" $DEBUG_FLAG -c -t $TTL $PTR_IP $PTR_HOSTNAME
    create_update-pdns-ptr-record.sh -C "$PDNS_CONF_DIR/pdns.conf" $DEBUG_FLAG -c -t $TTL $PTR_IP2 $PTR_HOSTNAME

    assertEquals "Wrong number of records in $PTR_ZONE_PART" 3 $($TEST_DIG +onesoa $PTR_ZONE_PART AXFR | wc -l)

    # delete 1 record with -D flag
    delete-pdns-ptr-record.sh -C "$PDNS_CONF_DIR/pdns.conf" $DEBUG_FLAG -D $PTR_IP2

    local PTR_NAME=$(get_ptr_host_part $PTR_IP2).$PTR_ZONE_PART
    local DIG_PTR_NAME
    # assert that zone and remaining record are still there
    eval $($TEST_DIG $PTR_ZONE_PART AXFR | awk '
        /[\t\s]SOA[\t\s]/{print "DIG_ZONE_NAME="$1};
        /[\t\s]PTR[\t\s]/{print "DIG_PTR_NAME="$1};
    ')

    assertEquals "Zone missing after deleting 1 of 2 PTR records in test zone" "$PTR_ZONE_PART" "$DIG_ZONE_NAME"
    assertEquals "Expected PTR record missing after deleting 1 of 2 PTR records in test zone" "$PTR_NAME"\
        "$DIG_PTR_NAME"

    # delete remaining PTR record with -D flag
    delete-pdns-ptr-record.sh -C "$PDNS_CONF_DIR/pdns.conf" $DEBUG_FLAG -D $PTR_IP

    # assert zone is gone
    assertEquals "'delete-pdns-ptr-record.sh -D ...' failed to delete empty zone"\
        "; Transfer failed." "$($TEST_DIG $PTR_ZONE_PART AXFR)"
}

testCreateUpdatePtrRecordWithDefaults(){
    local PTR_IP=$(_random_ipv4_octet).6.$(_random_ipv4_octet).$(_random_ipv4_octet)
    local PTR_HOSTNAME=$(_random_alphanumeric_chars 8).$(_random_alphanumeric_chars 3).tld.
    local PTR_ZONE_PART=$(get_ptr_zone_part $PTR_IP)
    local PTR_HOST_PART=$(get_ptr_host_part $PTR_IP)
    local TTL=86400
    local DEBUG_FLAG

    if [ "$ENABLE_DEBUG" == "true" ]; then
        DEBUG_FLAG=-d
    fi

    # attempt to create ptr record exercising all flags except -c
    local CREATE_OUT=$( 2>&1 create_update-pdns-ptr-record.sh -C "$PDNS_CONF_DIR/pdns.conf" $DEBUG_FLAG $PTR_IP \
        $PTR_HOSTNAME | head -1)

    # assert that it failed
    assertEquals "Inverse zone $PTR_ZONE_PART does not exist." "$CREATE_OUT"

    # create ptr record with -c flag
    create_update-pdns-ptr-record.sh -C "$PDNS_CONF_DIR/pdns.conf" $DEBUG_FLAG -c $PTR_IP $PTR_HOSTNAME

    # assert that it succeeded
    #local $DIG_OUT="$($TEST_DIG -x $PTR_IP)"
    local DIG_PTR_HOSTNAME
    local DIG_TTL
    eval $($TEST_DIG -x $PTR_IP | awk '
        /[\t\s]PTR[\t\s]/{
            print "DIG_TTL="$2;
            print "DIG_PTR_HOSTNAME="$5;
        }
    ')
    assertEquals "PTR TTL" "$TTL" "$DIG_TTL"
    assertEquals "PTR hostname" "$PTR_HOSTNAME" "$DIG_PTR_HOSTNAME"
}
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

if ! [ "$DEBUG_SHELL" == true ]; then
    DEBUG_SHELL=false
fi

declare PDNS_TEST_DATA_ROOT PDNS_PID PDNS_STDERR PDNS_STDOUT
PDNS_TEST_DNS_PORT=5354
PDNS_TEST_HTTP_PORT=8011
CACHE_TTL=1
SLEEP_TIME=$((CACHE_TTL+1))

# Alias dig with recurring options
# include +tcp so that dig fails fast if DNS server is down
TEST_DIG="dig @localhost +noquestion +nocomments +nocmd +nostats +tcp -p $PDNS_TEST_DNS_PORT"

_test_cleanup(){
    if $DEBUG_SHELL; then
        >&2 echo "Dropping to a shell for debugging purposes.  Exit to complete cleanup."
        pushd $PDNS_TEST_DATA_ROOT
        /bin/bash
        popd
    fi

    if [ -n "$PDNS_PID" ]; then
        if kill -TERM $PDNS_PID >/dev/null 2>&1; then
            >&2 echo "Terminated pdns_server pid $PDNS_PID"
        else
            >&2 echo "pdns_server pid $PDNS_PID died prematurely.  STDERR below..."
            >&2 cat "$PDNS_STDERR"
        fi
    fi
    >&2 echo "Deleting $PDNS_TEST_DATA_ROOT"
    rm -rf "$PDNS_TEST_DATA_ROOT"
    # since we displace _shunit_cleanup() with 'trap _test_cleanup EXIT', call it after test-specific cleanup is
    # complete
    _shunit_cleanup EXIT
}


# $1: number of random alphanumeric characters to output
_random_alphanumeric_chars(){
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        cat /dev/urandom | LC_CTYPE=C tr -dc 'a-z0-9' | head -c $1
    else
        return 1
    fi
}

# Echoes random number between 0 and 254
_random_ipv4_octet(){
    echo $((RANDOM % 255 ))
}

_wait_for_cache_expiry(){
    local
    if [ "$ENABLE_DEBUG" == "true" ]; then
        >&2 echo "Waiting $SLEEP_TIME seconds for PDNS cache to expire"
    fi
    sleep $SLEEP_TIME
}

oneTimeSetUp(){
    PDNS_TEST_DATA_ROOT="$(mktemp -d)"
    PDNS_CONF_DIR="$PDNS_TEST_DATA_ROOT/conf"
    PDNS_SQLITE_DIR="$PDNS_TEST_DATA_ROOT/var"
    PDNS_STDOUT="$PDNS_TEST_DATA_ROOT/pdns.out"
    PDNS_STDERR="$PDNS_TEST_DATA_ROOT/pdns.err"

    trap _test_cleanup EXIT

    # generate temporary pdns config / sqlite database
    /init-pdns-sqlite3-db-and-config.sh -n -C "$PDNS_CONF_DIR" -D "$PDNS_SQLITE_DIR"\
        -p $PDNS_TEST_DNS_PORT -P $CACHE_TTL -q $CACHE_TTL -H $PDNS_TEST_HTTP_PORT -s "$PDNS_TEST_DATA_ROOT"

    # start pdns_server, redirect stdout, stderr to files in $PDNS_TEST_DATA_ROOT and background
    >&2 echo "Starting test pdns_server from $PDNS_TEST_DATA_ROOT"
    pdns_server --config-dir="$PDNS_CONF_DIR" > "$PDNS_STDOUT" 2> "$PDNS_STDERR" &
    # save PID
    PDNS_PID=$!

    if ! ps -p $PDNS_PID; then
        >&2 echo "pdns_server failed to start."
        >&2 cat "$PDNS_STDERR"
        exit 1
    fi
}

ENABLE_DEBUG=true
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

if ! [ "$DEBUG_SHELL" == true ]; then
    DEBUG_SHELL=false
fi

declare PDNS_TEST_DATA_ROOT PDNS_PID PDNS_STDERR PDNS_STDOUT
PDNS_TEST_DNS_PORT=5354
PDNS_TEST_HTTP_PORT=8011
CACHE_TTL=1
SLEEP_TIME=$((CACHE_TTL+1))

# Alias dig with recurring options
# include +tcp so that dig fails fast if DNS server is down
TEST_DIG="dig @localhost +noquestion +nocomments +nocmd +nostats +tcp -p $PDNS_TEST_DNS_PORT"

_test_cleanup(){
    if $DEBUG_SHELL; then
        >&2 echo "Dropping to a shell for debugging purposes.  Exit to complete cleanup."
        pushd $PDNS_TEST_DATA_ROOT
        /bin/bash
        popd
    fi

    if [ -n "$PDNS_PID" ]; then
        if kill -TERM $PDNS_PID >/dev/null 2>&1; then
            >&2 echo "Terminated pdns_server pid $PDNS_PID"
        else
            >&2 echo "pdns_server pid $PDNS_PID died prematurely.  STDERR below..."
            >&2 cat "$PDNS_STDERR"
        fi
    fi
    >&2 echo "Deleting $PDNS_TEST_DATA_ROOT"
    rm -rf "$PDNS_TEST_DATA_ROOT"
    # since we displace _shunit_cleanup() with 'trap _test_cleanup EXIT', call it after test-specific cleanup is
    # complete
    _shunit_cleanup EXIT
}


# $1: number of random alphanumeric characters to output
_random_alphanumeric_chars(){
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        cat /dev/urandom | LC_CTYPE=C tr -dc 'a-z0-9' | head -c $1
    else
        return 1
    fi
}

# Echoes random number between 0 and 254
_random_ipv4_octet(){
    echo $((RANDOM % 255 ))
}

_wait_for_cache_expiry(){
    local
    if [ "$ENABLE_DEBUG" == "true" ]; then
        >&2 echo "Waiting $SLEEP_TIME seconds for PDNS cache to expire"
    fi
    sleep $SLEEP_TIME
}

oneTimeSetUp(){
    PDNS_TEST_DATA_ROOT="$(mktemp -d)"
    PDNS_CONF_DIR="$PDNS_TEST_DATA_ROOT/conf"
    PDNS_SQLITE_DIR="$PDNS_TEST_DATA_ROOT/var"
    PDNS_STDOUT="$PDNS_TEST_DATA_ROOT/pdns.out"
    PDNS_STDERR="$PDNS_TEST_DATA_ROOT/pdns.err"

    trap _test_cleanup EXIT

    # generate temporary pdns config / sqlite database
    /init-pdns-sqlite3-db-and-config.sh -n -C "$PDNS_CONF_DIR" -D "$PDNS_SQLITE_DIR"\
        -p $PDNS_TEST_DNS_PORT -P $CACHE_TTL -q $CACHE_TTL -H $PDNS_TEST_HTTP_PORT -s "$PDNS_TEST_DATA_ROOT"

    # start pdns_server, redirect stdout, stderr to files in $PDNS_TEST_DATA_ROOT and background
    >&2 echo "Starting test pdns_server from $PDNS_TEST_DATA_ROOT"
    pdns_server --config-dir="$PDNS_CONF_DIR" > "$PDNS_STDOUT" 2> "$PDNS_STDERR" &
    # save PID
    PDNS_PID=$!

    if ! ps -p $PDNS_PID; then
        >&2 echo "pdns_server failed to start."
        >&2 cat "$PDNS_STDERR"
        exit 1
    fi
}

source /shunit2