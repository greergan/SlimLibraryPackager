set(TEST_CPP "${CMAKE_CURRENT_SOURCE_DIR}/src/test.cpp")

if(EXISTS "${TEST_CPP}")
    add_executable(slim_test "${TEST_CPP}")
    target_compile_options(slim_test PRIVATE ${SLIM_CXX_FLAGS})
    if(HPP_HEADER_ONLY)
        target_include_directories(slim_test
            PRIVATE
                $<BUILD_INTERFACE:${slimlibrarysrc_SOURCE_DIR}/include>
                $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
        )
    else()
        target_link_libraries(slim_test PRIVATE ${SLIM_LIB_LOWER}_shared)
    endif()
    message(STATUS "Testing: with src/test.cpp")
    add_custom_command(TARGET slim_test POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "Running slim_test..."
        COMMAND $<TARGET_FILE:slim_test>
        COMMENT "Running slim_test"
    )
else()
    message(STATUS "Testing: src/test.cpp not found, skipping")
endif()
