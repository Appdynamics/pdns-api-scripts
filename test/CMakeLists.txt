# install scripts based on properties fed in from `brew`

# expand installation path @VARIABLE@ references in shell scripts
file(GLOB scripts "*.sh")
foreach(script ${scripts})
    configure_file(${script} ${CMAKE_CURRENT_BINARY_DIR}/${script} @ONLY)
endforeach()

foreach(script ${scripts})
    install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/${script} DESTINATION ${CMAKE_INSTALL_PREFIX}/test)
endforeach()
