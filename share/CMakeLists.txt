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

# install scripts based on properties fed in from `brew`

# expand installation path @VARIABLE@ references in shell scripts
file(GLOB scripts RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "*.sh")
foreach(script ${scripts})
    configure_file(${script} ${CMAKE_CURRENT_BINARY_DIR}/${script} @ONLY)
endforeach()

foreach(script ${scripts})
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${script} DESTINATION ${SHAREDIR})
endforeach()
