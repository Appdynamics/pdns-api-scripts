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

PROJECT("pdns-api-scripts")
cmake_minimum_required(VERSION 3.7)

if(${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_BINARY_DIR})
    message(FATAL_ERROR "In-source builds are not allowed.  Please build in a new directory.")
endif()

#FIXME:  this needs to go to share / package_name
if(NOT DEFINED SHAREDIR)
    if(CMAKE_INSTALL_PREFIX EQUAL "/")
        set(SHAREDIR /usr/share/${CMAKE_PROJECT_NAME})
    else()
        set(SHAREDIR ${CMAKE_INSTALL_PREFIX}/share/${CMAKE_PROJECT_NAME})
    endif()
endif()

if(NOT DEFINED SBINDIR)
    if(CMAKE_INSTALL_PREFIX EQUAL "/")
        set(SBINDIR /usr/sbin)
    else()
        set(SBINDIR ${CMAKE_INSTALL_PREFIX}/sbin)
    endif()
endif()

if(NOT DEFINED ETCDIR)
    set(ETCDIR ${CMAKE_INSTALL_PREFIX}/etc)
endif()

add_subdirectory(sbin)
add_subdirectory(share/pdns-api-scripts)
add_subdirectory(share/pdns-api-scripts/test)
add_subdirectory(share/man/man1)