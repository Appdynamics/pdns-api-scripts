#FIXME: add license header

# expand installation path @VARIABLE@ references in shell scripts
file(GLOB scripts RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "*.sh")
foreach(script ${scripts})
    configure_file(${script} ${CMAKE_CURRENT_BINARY_DIR}/${script}.out @ONLY)
endforeach()

# link test scripts for individual programs
file(GLOB test_scripts RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "test_*.sh")
foreach(test_script ${test_scripts})
    file(READ ${CMAKE_CURRENT_BINARY_DIR}/setup_and_teardown.sh.out FILE_CONTENT)
    file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/${test_script} "${FILE_CONTENT}")
    file(READ ${CMAKE_CURRENT_BINARY_DIR}/${test_script}.out FILE_CONTENT)
    file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/${test_script} "${FILE_CONTENT}")
    file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/${test_script} "source ${USR_BINDIR}/shunit2")
endforeach()

# link a test script for every program
file(READ ${CMAKE_CURRENT_BINARY_DIR}/setup_and_teardown.sh.out FILE_CONTENT)
file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/test_all_api_scripts.sh "${FILE_CONTENT}")
foreach(test_script ${test_scripts})
    file(READ ${CMAKE_CURRENT_BINARY_DIR}/${test_script}.out FILE_CONTENT)
    file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/test_all_api_scripts.sh "${FILE_CONTENT}")
endforeach()
file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/test_all_api_scripts.sh "source ${USR_BINDIR}/shunit2")

# install everything...
file(GLOB test_scripts RELATIVE ${CMAKE_CURRENT_BINARY_DIR} "test_*.sh")
foreach(script ${test_scripts})
    install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/${script} DESTINATION ${CMAKE_INSTALL_PREFIX}/test)
endforeach()