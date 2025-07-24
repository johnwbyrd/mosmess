# Prerequisites Test Suite
cmake_minimum_required(VERSION 3.25)
project(PrerequisiteTests LANGUAGES NONE)

# Enable testing
enable_testing()

# Set up test environment variables
set(PREREQUISITE_TEST_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
set(PREREQUISITE_TEST_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}")

# Include the Prerequisite module we're testing
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../dist/cmake")

# Function to add a prerequisite test with process isolation
function(add_prerequisite_test TEST_NAME)
    set(options EXPECT_FAIL)
    set(oneValueArgs TIMEOUT)
    set(multiValueArgs COMMAND CONFIG_ARGS)
    cmake_parse_arguments(APT "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Default timeout
    if(NOT APT_TIMEOUT)
        set(APT_TIMEOUT 30)
    endif()
    
    # Create test directory
    set(TEST_DIR "${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}")
    file(MAKE_DIRECTORY "${TEST_DIR}")
    
    # Create the test
    add_test(
        NAME ${TEST_NAME}
        COMMAND ${CMAKE_COMMAND}
            ${APT_CONFIG_ARGS}
            -S "${CMAKE_CURRENT_SOURCE_DIR}/${TEST_NAME}"
            -B "${TEST_DIR}"
        WORKING_DIRECTORY "${TEST_DIR}"
    )
    
    # Set test properties
    set_tests_properties(${TEST_NAME} PROPERTIES
        TIMEOUT ${APT_TIMEOUT}
        ENVIRONMENT "CTEST_OUTPUT_ON_FAILURE=1"
    )
    
    if(APT_EXPECT_FAIL)
        set_tests_properties(${TEST_NAME} PROPERTIES WILL_FAIL TRUE)
    endif()
    
    # Add build test if requested
    if(APT_COMMAND)
        add_test(
            NAME ${TEST_NAME}_build
            COMMAND ${CMAKE_COMMAND}
                --build "${TEST_DIR}"
                ${APT_COMMAND}
            WORKING_DIRECTORY "${TEST_DIR}"
        )
        set_tests_properties(${TEST_NAME}_build PROPERTIES
            DEPENDS ${TEST_NAME}
            TIMEOUT ${APT_TIMEOUT}
            ENVIRONMENT "CTEST_OUTPUT_ON_FAILURE=1"
        )
    endif()
endfunction()

# Basic functionality tests
add_prerequisite_test(hello_immediate)
add_prerequisite_test(hello_deferred COMMAND "--target hello_deferred-build")