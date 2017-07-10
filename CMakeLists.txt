# FIXME: add license header

cmake_minimum_required(VERSION 3.7)

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

add_subdirectory(sbin)
add_subdirectory(share)