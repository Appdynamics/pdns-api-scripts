#@IgnoreInspection BashAddShebang

#FIXME: add license header

if ! declare -f get_ptr_zone_part >/dev/null; then
    source @SHAREDIR@/pdns-api-script-functions.sh
fi

testCreateUpdateARecord(){
    local DEBUG_FLAG
    local ZONE_NAME=$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    local PRIMARY_MASTER=primary.master.$ZONE_NAME
    local RECORD_NAME=$(_random_alphanumeric_chars 11)
    local RECORD_IP=$(_random_ipv4_octet).$(_random_ipv4_octet).$(_random_ipv4_octet).$(_random_ipv4_octet)
    local TTL=85399
    local SCRIPT_STDERR="$(mktemp)"

    if [ "$ENABLE_DEBUG" == "true" ]; then
        DEBUG_FLAG=-d
    fi

    # attempt to create A record, exercise all script parameters
    create_update-pdns-a-record.sh -t $TTL -p $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" $RECORD_NAME.$ZONE_NAME\
        $RECORD_IP 2>"$SCRIPT_STDERR"

    # assert that the creation attempt failed because the zone didn't exist
    assertEquals  "Error: Zone '$ZONE_NAME' does not exist." "$(head -1 "$SCRIPT_STDERR")"
    rm -f "$SCRIPT_STDERR"

    # create zone
    create-pdns-zone.sh -C "$PDNS_CONF_DIR/pdns.conf" "$ZONE_NAME" "$PRIMARY_MASTER"

    # attempt to create A record, exercise all script parameters
    create_update-pdns-a-record.sh -t $TTL -p $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" $RECORD_NAME.$ZONE_NAME $RECORD_IP

    # assert that the A record was created with all script parameters present
    local DIG_TTL
    local DIG_RECORD_IP
    eval $($TEST_DIG $RECORD_NAME.$ZONE_NAME A | awk '
        /[\t\s]A[\t\s]/{
            if($1 == "'"$RECORD_NAME.$ZONE_NAME"'"){
                print "DIG_TTL="$2;
                print "DIG_RECORD_IP="$5
            }
        }
    ')
    assertEquals "A record ttl mismatch" "$TTL" "$DIG_TTL"
    assertEquals "A record IP mismatch" "$RECORD_IP" "$DIG_RECORD_IP"

    # assert that the A record's complementary PTR record was created with all script parameters present
    local PTR_RECORD_NAME=$(get_ptr_host_part $RECORD_IP).$(get_ptr_zone_part $RECORD_IP)
    local DIG_PTR_FQDN
    eval $($TEST_DIG @localhost -p $PDNS_TEST_DNS_PORT -x $RECORD_IP | awk '
        /[\t\s]PTR[\t\s]/{
            if($1 == "'"$PTR_RECORD_NAME"'"){
                print "DIG_TTL="$2;
                print "DIG_PTR_FQDN="$5;
            }
        }
    ')
    assertEquals "PTR record ttl mismatch" "$TTL" "$DIG_TTL"
    assertEquals "PTR record FQDN mismatch" "$RECORD_NAME.$ZONE_NAME" "$DIG_PTR_FQDN"

    # update the A record with different parameters
    RECORD_IP=$(_random_ipv4_octet).$(_random_ipv4_octet).$(_random_ipv4_octet).$(_random_ipv4_octet)
    TTL=86401
    create_update-pdns-a-record.sh -t $TTL -p $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" $RECORD_NAME.$ZONE_NAME $RECORD_IP

    # assert that the A record was updated with all script parameters
    local DIG_TTL
    local DIG_RECORD_IP
    eval $($TEST_DIG $RECORD_NAME.$ZONE_NAME A | awk '
        /[\t\s]A[\t\s]/{
            if($1 == "'"$RECORD_NAME.$ZONE_NAME"'"){
                print "DIG_TTL="$2;
                print "DIG_RECORD_IP="$5
            }
        }
    ')

    assertEquals "A record ttl mismatch after update" "$TTL" "$DIG_TTL"
    assertEquals "A record IP mismatch after update" "$RECORD_IP" "$DIG_RECORD_IP"

    # assert that the PTR record was updated with all script parameters
    PTR_RECORD_NAME=$(get_ptr_host_part $RECORD_IP).$(get_ptr_zone_part $RECORD_IP)
    eval $($TEST_DIG @localhost -p $PDNS_TEST_DNS_PORT -x $RECORD_IP | awk '
        /[\t\s]PTR[\t\s]/{
            if($1 == "'"$PTR_RECORD_NAME"'"){
                print "DIG_TTL="$2;
                print "DIG_PTR_FQDN="$5;
            }
        }
    ')

    assertEquals "PTR record ttl mismatch after update" "$TTL" "$DIG_TTL"
    assertEquals "PTR record FQDN mismatch after update" "$RECORD_NAME.$ZONE_NAME" "$DIG_PTR_FQDN"

    # delete the zone
    delete-pdns-zone.sh "$ZONE_NAME"
}

testDeleteArecord(){
    local DEBUG_FLAG

    if [ "$ENABLE_DEBUG" == "true" ]; then
        DEBUG_FLAG=-d
    fi

    # create forward zone
    # create A record with -p option
    # assert A record and PTR record are there
    # delete A record without -p option
    # assert that A record is gone and PTR record is still there
    # create different A record with previous IP
    # assert A record is there
    # attempt to delete A record with -p option
    # assert that delete-pdns-a-record.sh exited with appropriate warning
    # assert that mismatched A and PTR records are still present.
    # delete A and PTR records individually
    # create A record with -p option
    # assert A record and PTR record are there
    # delete A record with -p option
    # assert that A and PTR records are gone
    fail "Test not fully implemented" #FIXME: placeholder
}

testCreateAAndPTRRecordWithDefaults(){
    local DEBUG_FLAG

    if [ "$ENABLE_DEBUG" == "true" ]; then
        DEBUG_FLAG=-d
    fi

    fail "Test not fully implemented" #FIXME: placeholder
}

testCreateARecordWithDefaults(){
    local DEBUG_FLAG

    if [ "$ENABLE_DEBUG" == "true" ]; then
        DEBUG_FLAG=-d
    fi

    fail "Test not fully implemented" #FIXME: placeholder
}