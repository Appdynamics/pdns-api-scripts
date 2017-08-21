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

cmake_minimum_required(VERSION 3.7)

if(${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_BINARY_DIR})
    message(FATAL_ERROR "In-source builds are not allowed.  Please build in a new directory.")
endif()

if(NOT DEFINED SHAREDIR)
    if(CMAKE_INSTALL_PREFIX EQUAL "/")
        set(SHAREDIR /usr/share)
    else()
        set(SHAREDIR ${CMAKE_INSTALL_PREFIX}/share)
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

if(NOT DEFINED USR_BINDIR)
    if(CMAKE_INSTALL_PREFIX EQUAL "/")
        set(USR_BINDIR /usr/bin)
    else()
        set(USR_BINDIR ${CMAKE_INSTALL_PREFIX}/bin)
    endif()
endif()

if (NOT DEFINED PDNS_SQLITE_LIBEXEC)
    if(CMAKE_INSTALL_PREFIX EQUAL "/")
        set(PDNS_SQLITE_LIBEXEC /usr/libexec)
    else()
        set(PDNS_SQLITE_LIBEXEC ${CMAKE_INSTALL_PREFIX}/libexec)
    endif()
endif()

add_subdirectory(sbin)
add_subdirectory(share)
add_subdirectory(test)