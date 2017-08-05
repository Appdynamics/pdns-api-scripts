# FIXME: add license header

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