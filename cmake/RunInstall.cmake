string(REGEX REPLACE "^include/" "" SLIM_INSTALL_DIR "${SLIM_INCLUDE_DIR}")
if(HPP_HEADER_ONLY)
    install(FILES "${HPP_OUT_FILE}" DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${SLIM_INSTALL_DIR})
else()
    install(FILES "${H_OUT_FILE}" DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${SLIM_INSTALL_DIR})
endif()

if(NOT HPP_HEADER_ONLY)
    install(EXPORT ${SLIM_LIB}Targets
        FILE ${SLIM_LIB}Targets.cmake
        NAMESPACE Slim::
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${SLIM_LIB}
    )

    write_basic_package_version_file(
        "${CMAKE_CURRENT_BINARY_DIR}/${SLIM_LIB}ConfigVersion.cmake"
        VERSION ${GIT_TAG}
        COMPATIBILITY AnyNewerVersion
    )

    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/${SLIM_LIB}Config.cmake"
"include(\"\${CMAKE_CURRENT_LIST_DIR}/${SLIM_LIB}Targets.cmake\")\n")

    install(FILES
        "${CMAKE_CURRENT_BINARY_DIR}/${SLIM_LIB}Config.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/${SLIM_LIB}ConfigVersion.cmake"
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${SLIM_LIB}
    )
endif()

configure_file(
    "${slimlibrarysrc_SOURCE_DIR}/${SLIM_METADATA_FILE_IN}"
    "${CMAKE_CURRENT_BINARY_DIR}/${SLIM_METADATA_FILE_OUT}"
    @ONLY
)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/${SLIM_METADATA_FILE_OUT}"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig
)