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

# expand installation path @VARIABLE@ references in shell scripts
file(GLOB scripts RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "*.sh")

foreach(script ${scripts})
    configure_file(${script} ${CMAKE_CURRENT_BINARY_DIR}/${script}.out @ONLY)
endforeach()

# link test scripts for individual programs
file(GLOB test_scripts RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "test_*.sh")
foreach(test_script ${test_scripts})
    file(READ ${CMAKE_CURRENT_BINARY_DIR}/pdns-api-test-functions.sh.out FILE_CONTENT)
    file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/${test_script} "${FILE_CONTENT}\n")
    # enable debugging outut for testing of individual programs
    file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/${test_script} "ENABLE_DEBUG=true\n")
    file(READ ${CMAKE_CURRENT_BINARY_DIR}/${test_script}.out FILE_CONTENT)
    file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/${test_script} "${FILE_CONTENT}\n")
    file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/${test_script} "source ${USR_BINDIR}/shunit2")
endforeach()

# link a test script for every program
file(READ ${CMAKE_CURRENT_BINARY_DIR}/pdns-api-test-functions.sh.out FILE_CONTENT)
file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/test_all_api_scripts.sh "${FILE_CONTENT}\n")
foreach(test_script ${test_scripts})
    file(READ ${CMAKE_CURRENT_BINARY_DIR}/${test_script}.out FILE_CONTENT)
    file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/test_all_api_scripts.sh "${FILE_CONTENT}\n")
endforeach()
file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/test_all_api_scripts.sh "source ${USR_BINDIR}/shunit2")

# install everything...
file(GLOB install_scripts RELATIVE ${CMAKE_CURRENT_BINARY_DIR} "${CMAKE_CURRENT_BINARY_DIR}/test_*.sh")
foreach(script ${install_scripts})
    install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/${script} DESTINATION ${SHAREDIR}/test)
endforeach()
