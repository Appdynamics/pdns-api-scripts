#!/bin/bash

declare PDNS_TEST_DATA_ROOT PDNS_PID
PDNS_TEST_DNS_PORT=5353
PDNS_TEST_HTTP_PORT=8011

# Alias dig for sparse output
DIG="dig @localhost +noquestion +nocomments +nocmd +nostats -p $PDNS_TEST_DNS_PORT"

_cleanup(){
    if [ -n "$PDNS_PID" ]; then
        >&2 echo "Terminating pdns_server pid $PDNS_PID"
        kill -TERM $PDNS_PID
    fi
    >&2 echo "Deleting $PDNS_TEST_DATA_ROOT"
    rm -rf "$PDNS_TEST_DATA_ROOT"
}

# $1: number of random alphanumeric characters to output
_random_alphanumeric_chars(){
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        cat /dev/urandom | LC_CTYPE=C tr -dc 'a-zA-Z0-9' | head -c $1
    else
        return 1
    fi
}

oneTimeSetup(){
    PDNS_TEST_DATA_ROOT="$(mktemp)"
    PDNS_CONF_DIR="$PDNS_TEST_DATA_ROOT/conf"
    PDNS_SQLITE_DIR="$PDNS_TEST_DATA_ROOT/var"
    PDNS_STDOUT="$PDNS_TEST_DATA_ROOT/pdns.out"
    PDNS_STDERR="$PDNS_TEST_DATA_ROOT/pdns.err"

    trap _cleanup EXIT

    # generate temporary pdns config / sqlite database
    @PDNS_SQLITE_LIBEXEC@/init-pdns-sqlite3-db-and-config.sh -n -C "$PDNS_CONF_DIR" -D "$PDNS_SQLITE_DIR"\
        -p $PDNS_TEST_DNS_PORT -H $PDNS_TEST_HTTP_PORT

    # start pdns_server, redirect stdout, stderr to files in $PDNS_TEST_DATA_ROOT and background
    >&2 echo "Starting test pdns_server from $PDNS_TEST_DATA_ROOT"
    pdns_server --config-dir "$PDNS_CONF_DIR" > "$PDNS_STDOUT" 2> "$PDNS_STDERR"
    # save PID
    PDNS_PID=$!

    if ! ps -p $PDNS_PID; then
        >&2 echo "pdns_server failed to start."
        >&2 cat "$PDNS_STDERR"
        exit 1
    fi
}