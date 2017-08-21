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

testCreateUpdateDeleteCnameRecord(){
    local DEBUG_FLAG
    local ZONE_NAME=$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    local PRIMARY_MASTER=primary.master.$ZONE_NAME
    local RECORD_NAME=$(_random_alphanumeric_chars 11)
    local CNAME_TARGET=$(_random_alphanumeric_chars 11).$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    local TTL=85399
    local SCRIPT_STDERR="$(mktemp)"

    if [ "$ENABLE_DEBUG" == "true" ]; then
        DEBUG_FLAG=-d
    fi

    # attempt to create cname record
    create_update-pdns-cname-record.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" -t $TTL\
        $RECORD_NAME.$ZONE_NAME $CNAME_TARGET 2>"$SCRIPT_STDERR"

    # assert that the creation attempt failed because the zone didn't exist
    assertEquals  "Error: Zone '$ZONE_NAME' does not exist." "$(head -1 "$SCRIPT_STDERR")"
    rm -f "$SCRIPT_STDERR"

    # create zone
    create-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" $ZONE_NAME $PRIMARY_MASTER

    # create cname
    # attempt to create cname record
    create_update-pdns-cname-record.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" -t $TTL\
        $RECORD_NAME.$ZONE_NAME $CNAME_TARGET

    _wait_for_cache_expiry

    # assert that the CNAME record was created with all script parameters present
    local DIG_TTL
    local DIG_CNAME_TARGET
    eval $($TEST_DIG $RECORD_NAME.$ZONE_NAME CNAME | awk '
        /[\t\s]CNAME[\t\s]/{
            if($1 == "'"$RECORD_NAME.$ZONE_NAME"'"){
                print "DIG_TTL="$2;
                print "DIG_CNAME_TARGET="$5
            }
        }
    ')
    assertEquals "CNAME record ttl mismatch" "$TTL" "$DIG_TTL"
    assertEquals "CNAME record target mismatch" "$CNAME_TARGET" "$DIG_CNAME_TARGET"


    # update cname
    CNAME_TARGET=$(_random_alphanumeric_chars 11).$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    TTL=86401
    create_update-pdns-cname-record.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" -t $TTL\
        $RECORD_NAME.$ZONE_NAME $CNAME_TARGET

    _wait_for_cache_expiry

    # assert that it updated
    DIG_TTL=
    DIG_CNAME_TARGET=
    eval $($TEST_DIG $RECORD_NAME.$ZONE_NAME CNAME | awk '
        /[\t\s]CNAME[\t\s]/{
            if($1 == "'"$RECORD_NAME.$ZONE_NAME"'"){
                print "DIG_TTL="$2;
                print "DIG_CNAME_TARGET="$5
            }
        }
    ')
    assertEquals "CNAME record ttl mismatch after update" "$TTL" "$DIG_TTL"
    assertEquals "CNAME record target mismatch after update" "$CNAME_TARGET" "$DIG_CNAME_TARGET"

    # delete cname
    delete-pdns-cname-record.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" $RECORD_NAME.$ZONE_NAME

    _wait_for_cache_expiry

    # assert that PTR record is gone
    DIG_CNAME_TARGET=
    eval $($TEST_DIG $RECORD_NAME.$ZONE_NAME CNAME | awk '
        /[\t\s]CNAME[\t\s]/{
            if($1 == "'"$RECORD_NAME.$ZONE_NAME"'"){
                print "DIG_CNAME_TARGET="$5
            }
        }
    ')
    assertEquals "CNAME record still present after delete" "" "$DIG_RECORD_IP"

    # delete zone
    delete-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" $ZONE_NAME
}

testCreateDeleteCnameRecordWithDefaults(){
    local DEBUG_FLAG
    local ZONE_NAME=$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    local PRIMARY_MASTER=primary.master.$ZONE_NAME
    local RECORD_NAME=$(_random_alphanumeric_chars 11)
    local CNAME_TARGET=$(_random_alphanumeric_chars 11).$(_random_alphanumeric_chars 3).$(_random_alphanumeric_chars 3).tld.
    local TTL=86400
    local SCRIPT_STDERR="$(mktemp)"

    if [ "$ENABLE_DEBUG" == "true" ]; then
        DEBUG_FLAG=-d
    fi

        # create zone
    create-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" $ZONE_NAME $PRIMARY_MASTER

    # create cname
    # attempt to create cname record
    create_update-pdns-cname-record.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" $RECORD_NAME.$ZONE_NAME \
        $CNAME_TARGET

    _wait_for_cache_expiry

    _wait_for_cache_expiry

    # assert that the CNAME record was created with expected defaults
    local DIG_TTL
    local DIG_CNAME_TARGET
    eval $($TEST_DIG $RECORD_NAME.$ZONE_NAME CNAME | awk '
        /[\t\s]CNAME[\t\s]/{
            if($1 == "'"$RECORD_NAME.$ZONE_NAME"'"){
                print "DIG_TTL="$2;
                print "DIG_CNAME_TARGET="$5
            }
        }
    ')
    assertEquals "CNAME record ttl mismatch" "$TTL" "$DIG_TTL"
    assertEquals "CNAME record target mismatch" "$CNAME_TARGET" "$DIG_CNAME_TARGET"

    # delete zone
    delete-pdns-zone.sh $DEBUG_FLAG -C "$PDNS_TEST_DATA_ROOT/conf/pdns.conf" $ZONE_NAME
}