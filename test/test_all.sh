#!/bin/bash

#FIXME: add license header

TEST_DIR="$(dirname ${BASH_SOURCE[0]})"

source "$TEST_DIR/setup_and_teardown.sh"

# TODO: create an shunit2-based test file for each of the scripts above:
#  * Exercise input error handling
#  * Exercise non-existent zone handling

source "$TEST_DIR/test_create_delete_zone.sh"
source "$TEST_DIR/test_create_update_delete_a_record.sh"


source "@USR_BINDIR@/shunit2"