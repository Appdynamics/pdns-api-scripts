#!/bin/bash

#FIXME: add license header

if [ ${#BASH_SOURCE[@]} -eq 1 ]; then
    source "$(dirname ${BASH_SOURCE[0]})/setup_and_teardown.sh"
fi

testCreateUpdateARecord(){
    local ZONE_NAME=$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    local PRIMARY_MASTER=primary.master.$ZONE_NAME
    local RECORD_NAME=$(_random_alphanumeric_chars 11)
    local RECORD_IP=$(_random_ipv4_octet).$(_random_ipv4_octet).$(_random_ipv4_octet).$(_random_ipv4_octet)
    local TTL=85399

    # attempt to create A record, exercise all script parameters
    create_update-pdns-a-record.sh -t $TTL -p -d -C "$PDNS_CONF_DIR/pdns.conf" $RECORD_NAME.$ZONE_NAME $RECORD_IP
    # assert that the creation attempt failed because the zone didn't exist
    assertEquals "create_update-pdns-a-record.sh should have exited exit code 1" 1 $?

    # create zone
    # attempt to create A record, exercise all script parameters
    # assert that the A record was created with all script parameters present
    # assert that the A record's complementary PTR record was created

    # update the A record with different parameters
    # assert that the A record was updated with all script parameters present

    # delete the A record
    # assert the A record was deleted
    # delete the zone
    fail "Test not fully implemented" #FIXME: placeholder
}
export -f testCreateUpdateARecord

testUpdateARecordWithDefaults(){
    fail "Test not fully implemented" #FIXME: placeholder
}


if [ ${#BASH_SOURCE[@]} -eq 1 ]; then
    source "@USR_BINDIR@/shunit2"
fi