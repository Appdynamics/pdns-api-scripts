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

testCreateAndDeleteZone(){
    local ZONE_NAME=$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    local PRIMARY_MASTER=primary.master.$ZONE_NAME
    local MASTER_2=secondary.master.$ZONE_NAME
    local MASTER_3=tertiary.master.$ZONE_NAME
    local HOSTMASTER_EMAIL=$(_random_alphanumeric_chars 8)@$ZONE_NAME
    local TTL=85399
    local REFRESH=1199
    local RETRY=179
    local EXPIRY=1209599
    local NEG_TTL=61
    local NS_TTL=1209601
    local DEBUG_FLAG

    if [ "$ENABLE_DEBUG" == "true" ]; then
        DEBUG_FLAG=-d
    fi

    # create a zone and exercise all script params
    create-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" -H $HOSTMASTER_EMAIL -t $TTL -r $REFRESH \
        -R $RETRY -e $EXPIRY -n $NEG_TTL -N $NS_TTL $ZONE_NAME $PRIMARY_MASTER $MASTER_2 $MASTER_3

    # dig ... AXFR prints SOA records on the first and last line by design
    local DIG_OUT="$($TEST_DIG +onesoa $ZONE_NAME AXFR)"
    if [ "$DIG_OUT" == "; Transfer failed." ]; then
        >&2 echo "testCreateAndDeleteZone '$TEST_DIG +onesoa $ZONE_NAME AXFR' failed."
        >&2 echo "pdns_server STDOUT:"
        >&2 cat "$PDNS_STDOUT"
        >&2 echo "pdns_server STDERR:"
        >&2 cat "$PDNS_STDERR"
        fail
    else
        local DIG_ZONE_NAME
        local DIG_HOSTMASTER_EMAIL
        local DIG_TTL
        local DIG_REFRESH
        local DIG_RETRY
        local DIG_EXPIRY
        local DIG_NEG_TTL
        local DIG_PRIMARY_MASTER_TTL
        local DIG_MASTER_2_TTL
        local DIG_MASTER_3_TTL

        eval $(echo "$DIG_OUT" | awk '
            /\tSOA\t/{
                print "DIG_ZONE_NAME="$1;
                print "DIG_TTL="$2;
                print "DIG_PRIMARY_MASTER="$5;
                sub(/\./, "@", $6);
                print "DIG_HOSTMASTER_EMAIL="$6
                print "DIG_REFRESH="$8;
                print "DIG_RETRY="$9;
                print "DIG_EXPIRY="$10;
                print "DIG_NEG_TTL="$11;
            }
            /\tNS\t'"$PRIMARY_MASTER"'$/{
                print "DIG_PRIMARY_MASTER_TTL="$2;
            }
            /\tNS\t'"$MASTER_2"'$/{
                print "DIG_MASTER_2_TTL="$2
            }
            /\tNS\t'"$MASTER_3"'$/{
                print "DIG_MASTER_3_TTL="$2
            }
        ')

        assertEquals 'Zone name' "$ZONE_NAME" "$DIG_ZONE_NAME"
        assertEquals 'Hostmaster email' "$HOSTMASTER_EMAIL" "$DIG_HOSTMASTER_EMAIL"
        assertEquals 'Zone TTL' "$TTL" "$DIG_TTL"
        assertEquals 'Zone referesh interval' "$REFRESH" "$DIG_REFRESH"
        assertEquals 'Zone retry interval' "$RETRY" "$DIG_RETRY"
        assertEquals 'Zone expiry time' "$EXPIRY" "$DIG_EXPIRY"
        assertEquals 'Zone NXDOMAIN TTL' "$NEG_TTL" "$DIG_NEG_TTL"
        assertEquals 'Primary NS record TTL' "$NS_TTL" "$DIG_PRIMARY_MASTER_TTL"
        assertEquals 'Secondary NS record TTL' "$NS_TTL" "$DIG_MASTER_2_TTL"
        assertEquals 'Tertiary NS record TTL' "$NS_TTL" "$DIG_MASTER_3_TTL"
    fi

    # delete zone
    delete-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" $ZONE_NAME

    # assert that zone was deleted
    assertEquals "Failed to delete test zone. " "; Transfer failed." "$($TEST_DIG +onesoa $ZONE_NAME AXFR)"
}

testCreateAndDeleteZoneWithDefaults(){
    local ZONE_NAME=$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    local PRIMARY_MASTER=primary.master.$ZONE_NAME
    local MASTER_2=secondary.master.$ZONE_NAME
    local MASTER_3=tertiary.master.$ZONE_NAME
    local HOSTMASTER_EMAIL=$(whoami)@$(hostname -s).corp.appdynamics.com.
    local TTL=86400
    local REFRESH=1200
    local RETRY=180
    local EXPIRY=1209600
    local NEG_TTL=60
    local NS_TTL=1209600
    local DEBUG_FLAG

    if [ "$ENABLE_DEBUG" == "true" ]; then
        DEBUG_FLAG=-d
    fi

    # create a zone and exercise all script params
    create-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" $ZONE_NAME $PRIMARY_MASTER $MASTER_2 $MASTER_3

    # dig ... AXFR prints SOA records on the first and last line by design
    local DIG_OUT="$($TEST_DIG +onesoa $ZONE_NAME AXFR)"
    if [ "$DIG_OUT" == "; Transfer failed." ]; then
        >&2 echo "testCreateAndDeleteZoneWithDefaults '$TEST_DIG +onesoa $ZONE_NAME AXFR' failed."
        >&2 echo "pdns_server STDOUT:"
        >&2 cat "$PDNS_STDOUT"
        >&2 echo "pdns_server STDERR:"
        >&2 cat "$PDNS_STDERR"
        fail
    else
        local DIG_ZONE_NAME
        local DIG_HOSTMASTER_EMAIL
        local DIG_TTL
        local DIG_REFRESH
        local DIG_RETRY
        local DIG_EXPIRY
        local DIG_NEG_TTL
        local DIG_PRIMARY_MASTER_TTL
        local DIG_MASTER_2_TTL
        local DIG_MASTER_3_TTL

        eval $(echo "$DIG_OUT" | awk '
            /\tSOA\t/{
                print "DIG_ZONE_NAME="$1;
                print "DIG_TTL="$2;
                print "DIG_PRIMARY_MASTER="$5;
                sub(/\./, "@", $6);
                print "DIG_HOSTMASTER_EMAIL="$6
                print "DIG_REFRESH="$8;
                print "DIG_RETRY="$9;
                print "DIG_EXPIRY="$10;
                print "DIG_NEG_TTL="$11;
            }
            /\tNS\t'"$PRIMARY_MASTER"'$/{
                print "DIG_PRIMARY_MASTER_TTL="$2;
            }
            /\tNS\t'"$MASTER_2"'$/{
                print "DIG_MASTER_2_TTL="$2
            }
            /\tNS\t'"$MASTER_3"'$/{
                print "DIG_MASTER_3_TTL="$2
            }
        ')

        assertEquals 'Zone name' "$ZONE_NAME" "$DIG_ZONE_NAME"
        assertEquals 'Hostmaster email' "$HOSTMASTER_EMAIL" "$DIG_HOSTMASTER_EMAIL"
        assertEquals 'Zone TTL' "$TTL" "$DIG_TTL"
        assertEquals 'Zone referesh interval' "$REFRESH" "$DIG_REFRESH"
        assertEquals 'Zone retry interval' "$RETRY" "$DIG_RETRY"
        assertEquals 'Zone expiry time' "$EXPIRY" "$DIG_EXPIRY"
        assertEquals 'Zone NXDOMAIN TTL' "$NEG_TTL" "$DIG_NEG_TTL"
        assertEquals 'Primary NS record TTL' "$NS_TTL" "$DIG_PRIMARY_MASTER_TTL"
        assertEquals 'Secondary NS record TTL' "$NS_TTL" "$DIG_MASTER_2_TTL"
        assertEquals 'Tertiary NS record TTL' "$NS_TTL" "$DIG_MASTER_3_TTL"
    fi

    # delete zone
    delete-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" $ZONE_NAME

    #assert that zone was deleted
    assertEquals "Failed to delete test zone. " "; Transfer failed." "$($TEST_DIG +onesoa $ZONE_NAME AXFR)"
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