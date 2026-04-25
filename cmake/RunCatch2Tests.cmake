if(EXISTS "${slimlibrarysrc_SOURCE_DIR}/tests")
    message(STATUS "Catch2 Testing: enabled")

    file(GLOB_RECURSE SLIM_TEST_SOURCES "${slimlibrarysrc_SOURCE_DIR}/tests/*.cpp")

    FetchContent_Declare(
        Catch2
        GIT_REPOSITORY https://github.com/catchorg/Catch2.git
        GIT_TAG v3.5.0
    )

    FetchContent_MakeAvailable(Catch2)

    enable_testing()

    add_executable(slim_tests ${SLIM_TEST_SOURCES})
    target_compile_options(slim_tests PRIVATE ${SLIM_CXX_FLAGS})
    if(HPP_HEADER_ONLY)
        target_include_directories(slim_tests
            PRIVATE
                $<BUILD_INTERFACE:${slimlibrarysrc_SOURCE_DIR}/include>
                $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
        )
    else()
        target_link_libraries(slim_tests PRIVATE ${SLIM_LIB_LOWER})
    endif()

    target_link_libraries(slim_tests PRIVATE Catch2::Catch2WithMain)

    include(CTest)
    include(Catch)
    catch_discover_tests(slim_tests)

    add_custom_command(TARGET slim_tests POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "Running slim_tests..."
        COMMAND $<TARGET_FILE:slim_tests>
        COMMENT "Running slim_tests"
    )
else()
    message(STATUS "Catch2 Testing: disabled (no tests directory found)")
endif()
