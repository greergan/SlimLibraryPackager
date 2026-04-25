if(NOT HPP_HEADER_ONLY)
	add_library(${SLIM_LIB_LOWER}_shared SHARED ${slimlibrarysrc_SOURCE_DIR}/src/main.cpp)

    # Fix #1: SOVERSION should be major version only, not full semver
    string(REGEX MATCH "^([0-9]+)" SLIM_VERSION_MAJOR "${GIT_TAG}")

	set_target_properties(${SLIM_LIB_LOWER}_shared PROPERTIES
    	OUTPUT_NAME ${SLIM_LIB_LOWER}
    	VERSION     ${GIT_TAG}
    	SOVERSION   ${SLIM_VERSION_MAJOR}
	)

	add_library(${SLIM_LIB_LOWER}_static STATIC ${slimlibrarysrc_SOURCE_DIR}/src/main.cpp)
	set_target_properties(${SLIM_LIB_LOWER}_static PROPERTIES OUTPUT_NAME ${SLIM_LIB_LOWER})

	foreach(t ${SLIM_LIB_LOWER}_shared ${SLIM_LIB_LOWER}_static)
		target_include_directories(${t}
			PUBLIC
				$<BUILD_INTERFACE:${slimlibrarysrc_SOURCE_DIR}/include>
				$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
				$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
		)
		target_compile_options(${t} PUBLIC ${SLIM_CXX_FLAGS})
		target_compile_features(${t} PUBLIC cxx_std_${SLIMLIB_CXX_STANDARD})
	endforeach()
	add_library(${SLIM_LIB_LOWER} ALIAS ${SLIM_LIB_LOWER}_shared)
	add_custom_command(TARGET ${SLIM_LIB_LOWER}_shared POST_BUILD
    	COMMAND ${CMAKE_COMMAND} -E echo "Shared lib: $<TARGET_FILE_NAME:${SLIM_LIB_LOWER}_shared>"
	)

	add_custom_command(TARGET ${SLIM_LIB_LOWER}_static POST_BUILD
    	COMMAND ${CMAKE_COMMAND} -E echo "Static lib: $<TARGET_FILE_NAME:${SLIM_LIB_LOWER}_static>"
	)

	install(TARGETS ${SLIM_LIB_LOWER}_shared ${SLIM_LIB_LOWER}_static
		EXPORT ${SLIM_LIB}Targets
		LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
		ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
		RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
	)
endif()