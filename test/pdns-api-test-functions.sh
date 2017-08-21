#!/bin/bash

#FIXME: add license header

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
    @PDNS_SQLITE_LIBEXEC@/init-pdns-sqlite3-db-and-config.sh -n -C "$PDNS_CONF_DIR" -D "$PDNS_SQLITE_DIR"\
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
