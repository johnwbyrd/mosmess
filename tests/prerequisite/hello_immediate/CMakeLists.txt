cmake_minimum_required(VERSION 3.25)

# Include Prerequisite module
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../../dist/cmake")
include(Prerequisite)

# Test: Simple immediate prerequisite that uses CMake for cross-platform compatibility
Prerequisite_Add(
    hello_immediate
    DOWNLOAD_COMMAND "${CMAKE_COMMAND}" -E echo "Hello from immediate prerequisite download step"
    BUILD_COMMAND "${CMAKE_COMMAND}" -E echo "Hello from immediate prerequisite build step"
)

# This should execute during configuration
message(STATUS "Test: hello_immediate configuration complete")

# Test that parsing worked by retrieving some properties
Prerequisite_Get_Property(hello_immediate BUILD_COMMAND build_cmd)
message(STATUS "Retrieved BUILD_COMMAND: ${build_cmd}")

Prerequisite_Get_Property(hello_immediate DOWNLOAD_COMMAND download_cmd)
message(STATUS "Retrieved DOWNLOAD_COMMAND: ${download_cmd}")

Prerequisite_Get_Property(hello_immediate PREFIX prefix_dir)
message(STATUS "Retrieved PREFIX: ${prefix_dir}")

Prerequisite_Get_Property(hello_immediate SOURCE_DIR source_dir)
message(STATUS "Retrieved SOURCE_DIR: ${source_dir}")

# Debug dump of all properties for hello_immediate
_Prerequisite_Debug_Dump(hello_immediate)

# Verify the prerequisite ran by checking for expected output
# Since we can't easily capture echo output during configure time,
# we'll enhance this test later to write to files we can check

project(HelloImmediateTest LANGUAGES NONE)