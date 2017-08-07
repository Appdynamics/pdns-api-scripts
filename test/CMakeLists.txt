#FIXME: add license header

# expand installation path @VARIABLE@ references in shell scripts
file(GLOB scripts RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "*.sh")
foreach(script ${scripts})
    configure_file(${script} ${CMAKE_CURRENT_BINARY_DIR}/${script} @ONLY)
endforeach()

# install everything...
file(GLOB install_scripts RELATIVE ${CMAKE_CURRENT_BINARY_DIR} "${CMAKE_CURRENT_BINARY_DIR}/*.sh")
foreach(script ${install_scripts})
    install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/${script} DESTINATION ${CMAKE_INSTALL_PREFIX}/test)
endforeach()
