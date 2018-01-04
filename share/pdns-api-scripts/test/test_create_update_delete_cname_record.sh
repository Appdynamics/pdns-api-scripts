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

testCreateUpdateDeleteCnameRecord(){
    local DEBUG_FLAG
    local ZONE_NAME=$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    local PRIMARY_MASTER=primary.master.$ZONE_NAME
    local RECORD_NAME=$(_random_alphanumeric_chars 11)
    local CNAME_TARGET=$(_random_alphanumeric_chars 11).$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    local TTL=85399
    local SCRIPT_STDERR="$(mktemp)"

    if [ "$ENABLE_DEBUG" == "true" ]; then
        DEBUG_FLAG=-d
    fi

    # attempt to create cname record
    create_update-pdns-cname-record.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" -t $TTL\
        $RECORD_NAME.$ZONE_NAME $CNAME_TARGET 2>"$SCRIPT_STDERR"

    # assert that the creation attempt failed because the zone didn't exist
    assertEquals  "Error: Zone '$ZONE_NAME' does not exist." "$(head -1 "$SCRIPT_STDERR")"
    rm -f "$SCRIPT_STDERR"

    # create zone
    create-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" $ZONE_NAME $PRIMARY_MASTER

    # create cname
    # attempt to create cname record
    create_update-pdns-cname-record.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" -t $TTL\
        $RECORD_NAME.$ZONE_NAME $CNAME_TARGET

    _wait_for_cache_expiry

    # assert that the CNAME record was created with all script parameters present
    local DIG_TTL
    local DIG_CNAME_TARGET
    eval $($TEST_DIG $RECORD_NAME.$ZONE_NAME CNAME | awk '
        /[\t\s]CNAME[\t\s]/{
            if($1 == "'"$RECORD_NAME.$ZONE_NAME"'"){
                print "DIG_TTL="$2;
                print "DIG_CNAME_TARGET="$5
            }
        }
    ')
    assertEquals "CNAME record ttl mismatch" "$TTL" "$DIG_TTL"
    assertEquals "CNAME record target mismatch" "$CNAME_TARGET" "$DIG_CNAME_TARGET"


    # update cname
    CNAME_TARGET=$(_random_alphanumeric_chars 11).$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    TTL=86401
    create_update-pdns-cname-record.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" -t $TTL\
        $RECORD_NAME.$ZONE_NAME $CNAME_TARGET

    _wait_for_cache_expiry

    # assert that it updated
    DIG_TTL=
    DIG_CNAME_TARGET=
    eval $($TEST_DIG $RECORD_NAME.$ZONE_NAME CNAME | awk '
        /[\t\s]CNAME[\t\s]/{
            if($1 == "'"$RECORD_NAME.$ZONE_NAME"'"){
                print "DIG_TTL="$2;
                print "DIG_CNAME_TARGET="$5
            }
        }
    ')
    assertEquals "CNAME record ttl mismatch after update" "$TTL" "$DIG_TTL"
    assertEquals "CNAME record target mismatch after update" "$CNAME_TARGET" "$DIG_CNAME_TARGET"

    # delete cname
    delete-pdns-cname-record.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" $RECORD_NAME.$ZONE_NAME

    _wait_for_cache_expiry

    # assert that PTR record is gone
    DIG_CNAME_TARGET=
    eval $($TEST_DIG $RECORD_NAME.$ZONE_NAME CNAME | awk '
        /[\t\s]CNAME[\t\s]/{
            if($1 == "'"$RECORD_NAME.$ZONE_NAME"'"){
                print "DIG_CNAME_TARGET="$5
            }
        }
    ')
    assertEquals "CNAME record still present after delete" "" "$DIG_CNAME_TARGET"

    # delete zone
    delete-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" $ZONE_NAME
}

# test for '@' record creation and deletion
testCreateDeleteAtCnameRecord(){
    local DEBUG_FLAG
    local ZONE_SUFFIX=$(_random_alphanumeric_chars 3).tld.
    local ZONE_NAME=$(_random_alphanumeric_chars 3).$ZONE_SUFFIX
    local PRIMARY_MASTER=primary.master.$ZONE_NAME
    local RECORD_NAME=$ZONE_NAME
    local CNAME_TARGET=$(_random_alphanumeric_chars 11).$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    local TTL=85399
    local SCRIPT_STDERR="$(mktemp)"

    if [ "$ENABLE_DEBUG" == "true" ]; then
        DEBUG_FLAG=-d
    fi

    # attempt to create cname record
    create_update-pdns-cname-record.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" -t $TTL\
        $RECORD_NAME $CNAME_TARGET 2>"$SCRIPT_STDERR"

    # assert that the creation attempt failed because the zone didn't exist
    assertEquals  "Error: Zone '$ZONE_SUFFIX' does not exist." "$(head -1 "$SCRIPT_STDERR")"
    rm -f "$SCRIPT_STDERR"

    # create zone
    create-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" $ZONE_NAME $PRIMARY_MASTER

    # create cname
    # attempt to create cname record
    create_update-pdns-cname-record.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" -t $TTL\
        $RECORD_NAME $CNAME_TARGET

    _wait_for_cache_expiry

    # assert that the CNAME record was created with all script parameters present
    local DIG_TTL
    local DIG_CNAME_TARGET
    eval $($TEST_DIG $RECORD_NAME CNAME | awk '
        /[\t\s]CNAME[\t\s]/{
            if($1 == "'"$RECORD_NAME"'"){
                print "DIG_TTL="$2;
                print "DIG_CNAME_TARGET="$5
            }
        }
    ')
    assertEquals "CNAME record ttl mismatch" "$TTL" "$DIG_TTL"
    assertEquals "CNAME record target mismatch" "$CNAME_TARGET" "$DIG_CNAME_TARGET"

    # delete cname
    delete-pdns-cname-record.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" $RECORD_NAME

    _wait_for_cache_expiry

    # assert that PTR record is gone
    DIG_CNAME_TARGET=
    eval $($TEST_DIG $RECORD_NAME CNAME | awk '
        /[\t\s]CNAME[\t\s]/{
            if($1 == "'"$RECORD_NAME"'"){
                print "DIG_CNAME_TARGET="$5
            }
        }
    ')
    assertEquals "CNAME record still present after delete" "" "$DIG_CNAME_TARGET"

    # delete zone
    delete-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" $ZONE_NAME
}

testCreateDeleteCnameRecordWithDefaults(){
    local DEBUG_FLAG
    local ZONE_NAME=$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    local PRIMARY_MASTER=primary.master.$ZONE_NAME
    local RECORD_NAME=$(_random_alphanumeric_chars 11)
    local CNAME_TARGET=$(_random_alphanumeric_chars 11).$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    local TTL=86400
    local SCRIPT_STDERR="$(mktemp)"

    if [ "$ENABLE_DEBUG" == "true" ]; then
        DEBUG_FLAG=-d
    fi

        # create zone
    create-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" $ZONE_NAME $PRIMARY_MASTER

    # create cname
    # attempt to create cname record
    create_update-pdns-cname-record.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" $RECORD_NAME.$ZONE_NAME \
        $CNAME_TARGET

    _wait_for_cache_expiry

    _wait_for_cache_expiry

    # assert that the CNAME record was created with expected defaults
    local DIG_TTL
    local DIG_CNAME_TARGET
    eval $($TEST_DIG $RECORD_NAME.$ZONE_NAME CNAME | awk '
        /[\t\s]CNAME[\t\s]/{
            if($1 == "'"$RECORD_NAME.$ZONE_NAME"'"){
                print "DIG_TTL="$2;
                print "DIG_CNAME_TARGET="$5
            }
        }
    ')
    assertEquals "CNAME record ttl mismatch" "$TTL" "$DIG_TTL"
    assertEquals "CNAME record target mismatch" "$CNAME_TARGET" "$DIG_CNAME_TARGET"

    # delete zone
    delete-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" $ZONE_NAME
}#!/bin/bash

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