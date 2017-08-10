#@IgnoreInspection BashAddShebang

#FIXME: add license header

source "@SHAREDIR@/pdns-api-script-functions.sh"

testCreateUpdatePtrRecord(){
    local PTR_IP=$(_random_ipv4_octet).$(_random_ipv4_octet).$(_random_ipv4_octet).$(_random_ipv4_octet)
    local PTR_HOSTNAME=$(_random_alphanumeric_chars 8).$(_random_alphanumeric_chars 3).tld.

    # attempt to create ptr record exercising all flags except -c
    local CREATE_OUT=$( 2>&1 create_update-pdns-ptr-record.sh -C "$PDNS_CONF_DIR/pdns.conf" -d -t 86401 $PTR_IP \
        $PTR_HOSTNAME | head -1)

    # assert that it failed
    assertEquals "Inverse zone $(get_ptr_zone_part $PTR_IP) does not exist." "$CREATE_OUT"

    # create ptr record with -c flag
    create_update-pdns-ptr-record.sh -C "$PDNS_CONF_DIR/pdns.conf" -d -c -t 86401 $PTR_IP $PTR_HOSTNAME

    # assert that it succeeded
    $DIG -x $PTR_IP

    # update ptr record
    # assert that it updated
    # delete ptr record
    # assert that PTR is gone,
    # assert zone is still there
    # recreate PTR record
    # delete PTR record with -D flag
    # assert zone is gone
    fail "Not yet fully implemented" #FIXME: placeholder
}

testCreateUpdatePtrRecordWithDefaults(){
    fail "Not yet fully implemented" #FIXME: placeholder
}
