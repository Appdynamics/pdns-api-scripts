#@IgnoreInspection BashAddShebang

#FIXME: add license header

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
