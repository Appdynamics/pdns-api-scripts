#!/bin/bash

if [ ${#BASH_SOURCE[@]} -eq 1 ]; then
    source "$(dirname ${BASH_SOURCE[0]})/setup_and_teardown.sh"
fi

testCreateAndDeleteZone(){
    local ZONE_NAME=$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    local PRIMARY_MASTER=primary.master.$ZONE_NAME
    local MASTER_2=secondary.master.$ZONE_NAME
    local MASTER_3=tertiary.master.$ZONE_NAME
    local HOSTMASTER_EMAIL=$(_random_alphanumeric_chars 8)@$ZONE_NAME
    local TTL=85399
    local ZONE_SERIAL=42
    local REFRESH=1199
    local RETRY=179
    local EXPIRY=1209599
    local NEG_TTL=61

    # create a zone and exercise all script params
    set -x
    create-pdns-zone.sh -C "$PDNS_CONF_DIR/pdns.conf" -H $HOSTMASTER_EMAIL -t $TTL -s $ZONE_SERIAL -r $REFRESH \
        -R $RETRY -e $EXPIRY -n $NEG_TTL $ZONE_NAME $PRIMARY_MASTER $MASTER_2 $MASTER_3
    set +x

    echo "Zone name: $ZONE_NAME"

    # FIXME: dig it and assert we got what we expected
    local DIG_OUT="$($DIG $ZONE_NAME AXFR)"
    if [ "$DIG_OUT" == "; Transfer failed." ]; then
        >&2 echo "pdns_server STDOUT:"
        >&2 cat "$PDNS_STDOUT"
        >&2 echo "pdns_server STDERR:"
        >&2 cat "$PDNS_STDERR"
    else
        >&2 echo "$DIG_OUT"
    fi

    # delete zone
    delete-pdns-zone.sh -C "$PDNS_CONF_DIR/pdns.conf" $ZONE_NAME

    # FIXME: assert that it's gone
}

testCreateAndDeleteZoneWithDefaults(){
    #FIXME: placeholder
    false
    # create a zone with default options
    # dig it to make sure we get what we expected
    # delete zone
    # assert that it's gone
}

if [ ${#BASH_SOURCE[@]} -eq 1 ]; then
    source "@USR_BINDIR@/shunit2"
fi