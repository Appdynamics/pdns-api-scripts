#@IgnoreInspection BashAddShebang

#FIXME: add license header

testCreateUpdateARecord(){
    local ZONE_NAME=$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    local PRIMARY_MASTER=primary.master.$ZONE_NAME
    local RECORD_NAME=$(_random_alphanumeric_chars 11)
    local RECORD_IP=$(_random_ipv4_octet).$(_random_ipv4_octet).$(_random_ipv4_octet).$(_random_ipv4_octet)
    local TTL=85399
    local SCRIPT_STDERR="$(mktemp)"

    # attempt to create A record, exercise all script parameters
    create_update-pdns-a-record.sh -t $TTL -p -d -C "$PDNS_CONF_DIR/pdns.conf" $RECORD_NAME.$ZONE_NAME $RECORD_IP \
        2>"$SCRIPT_STDERR"

    # assert that the creation attempt failed because the zone didn't exist
    assertEquals  "Error: Zone '$ZONE_NAME' does not exist." "$(head -1 "$SCRIPT_STDERR")"
    rm -f "$SCRIPT_STDERR"

    # create zone
    create-pdns-zone.sh -C "$PDNS_CONF_DIR/pdns.conf" "$ZONE_NAME" "$PRIMARY_MASTER"

    # attempt to create A record, exercise all script parameters
    create_update-pdns-a-record.sh -t $TTL -p -d -C "$PDNS_CONF_DIR/pdns.conf" $RECORD_NAME.$ZONE_NAME $RECORD_IP

    # assert that the A record was created with all script parameters present
    assertEquals "Expected, actual A records do not match:" \
        "$RECORD_NAME.$ZONE_NAME $TTL"$'\t'IN$'\t'A$'\t'"$RECORD_IP" \
        "$($TEST_DIG $RECORD_NAME.$ZONE_NAME A)"

    # assert that the A record's complementary PTR record was created
    # FIXME: ptr scripts seem woefully broken, test and fix them before continuing here...
    dig @localhost -p $PDNS_TEST_DNS_PORT -x $RECORD_IP

    # update the A record with different parameters
    # assert that the A record was updated with all script parameters present

    # delete the A record
    # assert the A record was deleted
    # delete the zone
    fail "Test not fully implemented" #FIXME: placeholder

}

testUpdateARecordWithDefaults(){
    fail "Test not fully implemented" #FIXME: placeholder
}
