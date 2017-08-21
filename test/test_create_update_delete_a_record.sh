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
    create-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" "$ZONE_NAME" "$PRIMARY_MASTER"

    # attempt to create A record, exercise all script parameters
    create_update-pdns-a-record.sh -t $TTL -p $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" $RECORD_NAME.$ZONE_NAME \
        $RECORD_IP

    _wait_for_cache_expiry

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
    eval $($TEST_DIG -x $RECORD_IP | awk '
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
    create_update-pdns-a-record.sh -t $TTL -p $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" $RECORD_NAME.$ZONE_NAME \
        $RECORD_IP

    _wait_for_cache_expiry

    # assert that the A record was updated with all script parameters
    local DIG_TTL
    local DIG_RECORD_IP
    eval $($TEST_DIG $RECORD_NAME.$ZONE_NAME A | awk '
        /[\t\s]A[\t\s]/{
            if($1 == "'"$RECORD_NAME.$ZONE_NAME"'"){
                print "DIG_TTL="$2;
                print "DIG_RECORD_IP="$5;
            }
        }
    ')

    assertEquals "A record ttl mismatch after update" "$TTL" "$DIG_TTL"
    assertEquals "A record IP mismatch after update" "$RECORD_IP" "$DIG_RECORD_IP"

    # assert that the PTR record was updated with all script parameters
    PTR_RECORD_NAME=$(get_ptr_host_part $RECORD_IP).$(get_ptr_zone_part $RECORD_IP)
    eval $($TEST_DIG -x $RECORD_IP | awk '
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
    delete-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" "$ZONE_NAME"
}

testDeleteARecord(){
    local DEBUG_FLAG
    local ZONE_NAME=$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    local PRIMARY_MASTER=primary.master.$ZONE_NAME
    local RECORD_NAME=$(_random_alphanumeric_chars 11)
    local RECORD_IP=$(_random_ipv4_octet).$(_random_ipv4_octet).$(_random_ipv4_octet).$(_random_ipv4_octet)

    if [ "$ENABLE_DEBUG" == "true" ]; then
        DEBUG_FLAG=-d
    fi

    # create forward zone
    create-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" "$ZONE_NAME" "$PRIMARY_MASTER"

    # create A record with -p option
    create_update-pdns-a-record.sh -p $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" $RECORD_NAME.$ZONE_NAME $RECORD_IP

    _wait_for_cache_expiry

    # assert A record and PTR record are there
    local DIG_RECORD_IP
    eval $($TEST_DIG $RECORD_NAME.$ZONE_NAME A | awk '
        /[\t\s]A[\t\s]/{
            if($1 == "'"$RECORD_NAME.$ZONE_NAME"'"){
                print "DIG_RECORD_IP="$5
            }
        }
    ')
    assertEquals "A record IP mismatch" "$RECORD_IP" "$DIG_RECORD_IP"

    local PTR_RECORD_NAME=$(get_ptr_host_part $RECORD_IP).$(get_ptr_zone_part $RECORD_IP)
    local DIG_PTR_FQDN
    eval $($TEST_DIG -x $RECORD_IP | awk '
        /[\t\s]PTR[\t\s]/{
            if($1 == "'"$PTR_RECORD_NAME"'"){
                print "DIG_PTR_FQDN="$5;
            }
        }
    ')
    assertEquals "PTR record FQDN mismatch" "$RECORD_NAME.$ZONE_NAME" "$DIG_PTR_FQDN"

    # delete A record without -p option
    delete-pdns-a-record.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" "$RECORD_NAME.$ZONE_NAME"

    _wait_for_cache_expiry

    # assert that A record is gone
    DIG_RECORD_IP=
    eval $($TEST_DIG $RECORD_NAME.$ZONE_NAME A | awk '
        /[\t\s]A[\t\s]/{
            if($1 == "'"$RECORD_NAME.$ZONE_NAME"'"){
                print "DIG_RECORD_IP="$5
            }
        }
    ')
    assertEquals "A record still present after delete" "" "$DIG_RECORD_IP"

    # assert PTR record is still there
    DIG_PTR_FQDN=
    eval $($TEST_DIG -x $RECORD_IP | awk '
        /[\t\s]PTR[\t\s]/{
            if($1 == "'"$PTR_RECORD_NAME"'"){
                print "DIG_PTR_FQDN="$5;
            }
        }
    ')
    assertEquals "PTR record not present, as expected, after A record deletion."\
        "$RECORD_NAME.$ZONE_NAME" "$DIG_PTR_FQDN"

    # create different A record with previous IP
    local OLD_RECORD_NAME=$RECORD_NAME
    RECORD_NAME=$(_random_alphanumeric_chars 11)
    create_update-pdns-a-record.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" $RECORD_NAME.$ZONE_NAME $RECORD_IP

    _wait_for_cache_expiry

    # assert A record is there
    DIG_RECORD_IP=
    eval $($TEST_DIG $RECORD_NAME.$ZONE_NAME A | awk '
        /[\t\s]A[\t\s]/{
            if($1 == "'"$RECORD_NAME.$ZONE_NAME"'"){
                print "DIG_RECORD_IP="$5
            }
        }
    ')
    assertEquals "A record IP mismatch" "$RECORD_IP" "$DIG_RECORD_IP"

    # attempt to delete A record with -p option
    local SCRIPT_OUTPUT=$(delete-pdns-a-record.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" -p $RECORD_NAME.$ZONE_NAME \
        2>&1)

    # assert that delete-pdns-a-record.sh exited with appropriate warning
    assertEquals "delete-pdns-a-record.sh did not fail with expected warning" \
        "A record for $RECORD_NAME.$ZONE_NAME
Does not match PTR record for $RECORD_IP
Exiting without changes." \
        "$SCRIPT_OUTPUT"

    # nothing should have changed, but just in case it did...
    _wait_for_cache_expiry

    # assert that mismatched A and PTR records are still present.
    DIG_RECORD_IP=
    eval $($TEST_DIG $RECORD_NAME.$ZONE_NAME A | awk '
        /[\t\s]A[\t\s]/{
            if($1 == "'"$RECORD_NAME.$ZONE_NAME"'"){
                print "DIG_RECORD_IP="$5
            }
        }
    ')
    assertEquals "Unexpected A record change." "$RECORD_IP" "$DIG_RECORD_IP"

    DIG_PTR_FQDN=
    eval $($TEST_DIG -x $RECORD_IP | awk '
        /[\t\s]PTR[\t\s]/{
            if($1 == "'"$PTR_RECORD_NAME"'"){
                print "DIG_PTR_FQDN="$5;
            }
        }
    ')
    assertEquals "Unexpected PTR record change." "$OLD_RECORD_NAME.$ZONE_NAME" "$DIG_PTR_FQDN"

    # delete A and PTR records individually
    delete-pdns-a-record.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" $RECORD_NAME.$ZONE_NAME
    delete-pdns-ptr-record.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" $RECORD_IP

    # create new A record with -p option
    create_update-pdns-a-record.sh -p $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" $RECORD_NAME.$ZONE_NAME $RECORD_IP

    _wait_for_cache_expiry

    # delete A record with -p option
    delete-pdns-a-record.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" -p $RECORD_NAME.$ZONE_NAME

    _wait_for_cache_expiry

    # assert that A and PTR records are gone
    DIG_RECORD_IP=
    eval $($TEST_DIG $RECORD_NAME.$ZONE_NAME A | awk '
        /[\t\s]A[\t\s]/{
            if($1 == "'"$RECORD_NAME.$ZONE_NAME"'"){
                print "DIG_RECORD_IP="$5
            }
        }
    ')
    assertEquals "A record still present after delete" "" "$DIG_RECORD_IP"

    # assert PTR record is still there
    DIG_PTR_FQDN=
    eval $($TEST_DIG -x $RECORD_IP | awk '
        /[\t\s]PTR[\t\s]/{
            if($1 == "'"$PTR_RECORD_NAME"'"){
                print "DIG_PTR_FQDN="$5;
            }
        }
    ')
    assertEquals "PTR record still present after delete" "" "$DIG_PTR_FQDN"

    # delete zone
    delete-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" $ZONE_NAME
}

testCreateAAndPTRRecordWithDefaults(){
    local DEBUG_FLAG
    local ZONE_NAME=$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    local PRIMARY_MASTER=primary.master.$ZONE_NAME
    local RECORD_NAME=$(_random_alphanumeric_chars 11)
    local RECORD_IP=$(_random_ipv4_octet).$(_random_ipv4_octet).$(_random_ipv4_octet).$(_random_ipv4_octet)
    local TTL=86400
    local SCRIPT_STDERR="$(mktemp)"

    if [ "$ENABLE_DEBUG" == "true" ]; then
        DEBUG_FLAG=-d
    fi

    # attempt to create A record
    create_update-pdns-a-record.sh -p $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" $RECORD_NAME.$ZONE_NAME\
        $RECORD_IP 2>"$SCRIPT_STDERR"

    # assert that the creation attempt failed because the zone didn't exist
    assertEquals  "Error: Zone '$ZONE_NAME' does not exist." "$(head -1 "$SCRIPT_STDERR")"
    rm -f "$SCRIPT_STDERR"

    # create zone
    create-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" "$ZONE_NAME" "$PRIMARY_MASTER"

    # attempt to create A record, -p flag, with default record parameters
    create_update-pdns-a-record.sh -p $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" $RECORD_NAME.$ZONE_NAME \
        $RECORD_IP

    _wait_for_cache_expiry

    # assert that the A record was created with expected defaults
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

    # assert that the A record's complementary PTR record was created with expected defaults
    local PTR_RECORD_NAME=$(get_ptr_host_part $RECORD_IP).$(get_ptr_zone_part $RECORD_IP)
    local DIG_PTR_FQDN
    DIG_TTL=
    eval $($TEST_DIG -x $RECORD_IP | awk '
        /[\t\s]PTR[\t\s]/{
            if($1 == "'"$PTR_RECORD_NAME"'"){
                print "DIG_TTL="$2;
                print "DIG_PTR_FQDN="$5;
            }
        }
    ')
    assertEquals "PTR record ttl mismatch" "$TTL" "$DIG_TTL"
    assertEquals "PTR record FQDN mismatch" "$RECORD_NAME.$ZONE_NAME" "$DIG_PTR_FQDN"

    # delete the zone
    delete-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" "$ZONE_NAME"
}

testCreateARecordWithDefaults(){
    local DEBUG_FLAG

    if [ "$ENABLE_DEBUG" == "true" ]; then
        DEBUG_FLAG=-d
    fi

    local DEBUG_FLAG
    local ZONE_NAME=$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    local PRIMARY_MASTER=primary.master.$ZONE_NAME
    local RECORD_NAME=$(_random_alphanumeric_chars 11)
    local RECORD_IP=$(_random_ipv4_octet).$(_random_ipv4_octet).$(_random_ipv4_octet).$(_random_ipv4_octet)
    local TTL=86400
    local SCRIPT_STDERR="$(mktemp)"

    if [ "$ENABLE_DEBUG" == "true" ]; then
        DEBUG_FLAG=-d
    fi

    # attempt to create A record
    create_update-pdns-a-record.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" $RECORD_NAME.$ZONE_NAME\
        $RECORD_IP 2>"$SCRIPT_STDERR"

    # assert that the creation attempt failed because the zone didn't exist
    assertEquals  "Error: Zone '$ZONE_NAME' does not exist." "$(head -1 "$SCRIPT_STDERR")"
    rm -f "$SCRIPT_STDERR"

    # create zone
    create-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" "$ZONE_NAME" "$PRIMARY_MASTER"

    # attempt to create A record, with default record parameters
    create_update-pdns-a-record.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" $RECORD_NAME.$ZONE_NAME \
        $RECORD_IP

    _wait_for_cache_expiry

    # assert that the A record was created with expected defaults
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

    # assert that the A record's complementary PTR record was NOT created
    local PTR_RECORD_NAME=$(get_ptr_host_part $RECORD_IP).$(get_ptr_zone_part $RECORD_IP)
    local DIG_PTR_FQDN
    eval $($TEST_DIG -x $RECORD_IP | awk '
        /[\t\s]PTR[\t\s]/{
            if($1 == "'"$PTR_RECORD_NAME"'"){
                print "DIG_PTR_FQDN="$5;
            }
        }
    ')
    assertEquals "PTR record created when it shouldn't have been" "" "$DIG_PTR_FQDN"

    # delete the zone
    delete-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_CONF_DIR/pdns.conf" "$ZONE_NAME"
}