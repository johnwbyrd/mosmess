#[=======================================================================[.rst:
Superninja
----------

Superninja provides CMake functions for integrating multiple projects into a
unified ninja build graph with configure-time dependency visibility.

Configuration Variables:

``SUPERNINJA_BASE``
  Base directory for dependency builds. If not set, uses ExternalProject's
  default pattern: ``<name>-prefix/src/<name>-build``

``SUPERNINJA_FORCE_RECONFIGURE``
  Forces reconfiguration even if ninja files exist. Default: OFF

Functions:

.. command:: Superninja_Declare

  Declare a dependency with source location and build configuration::

    Superninja_Declare(<name>
      [GIT_REPOSITORY <repository>]
      [GIT_TAG <tag>]
      [... other FetchContent arguments ...]
      CONFIGURE_COMMAND <command>
      [NINJA_FILE <path>]
    )

  If NINJA_FILE is not specified, it is automatically calculated based on
  SUPERNINJA_BASE or ExternalProject default patterns.

  CONFIGURE_COMMAND supports @VAR@ variable expansion:
  - @SUPERNINJA_SOURCE_DIR@ - Source directory from FetchContent
  - @SUPERNINJA_BINARY_DIR@ - Calculated binary directory
  - @SUPERNINJA_NINJA_FILE@ - Expected ninja file location
  - Standard CMake variables: @CMAKE_COMMAND@, etc.

.. command:: Superninja_Populate

  Download sources for a declared dependency::

    Superninja_Populate(<name>)

.. command:: Superninja_MakeAvailable

  Download sources and configure build systems::

    Superninja_MakeAvailable(<name1> [<name2> ...])

  Only reconfigures if ninja file doesn't exist or SUPERNINJA_FORCE_RECONFIGURE is set.
  Performs variable expansion on CONFIGURE_COMMAND before execution.

.. command:: Superninja_Finalize

  Generate master ninja file with subninja integration::

    Superninja_Finalize(
      OUTPUT <master-ninja-file>
      [DEPENDENCIES <target> DEPENDS_ON <dependency> ...]
    )

#]=======================================================================]

include(FetchContent)

if(NOT DEFINED SUPERNINJA_BASE)
  # Use ExternalProject default pattern when no base specified
endif()

if(NOT DEFINED SUPERNINJA_FORCE_RECONFIGURE)
  set(SUPERNINJA_FORCE_RECONFIGURE OFF)
endif()

function(Superninja_Declare name)
  set(options)
  set(oneValueArgs CONFIGURE_COMMAND NINJA_FILE)
  set(multiValueArgs)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT ARG_CONFIGURE_COMMAND)
    message(FATAL_ERROR "Superninja_Declare: CONFIGURE_COMMAND is required")
  endif()

  # TODO: Calculate automatic directories based on SUPERNINJA_BASE
  # TODO: Use ExternalProject pattern if SUPERNINJA_BASE not set
  # TODO: Store auto-calculated directories for variable expansion
  
  # Store metadata
  set_property(GLOBAL APPEND PROPERTY _SUPERNINJA_DECLARED_DEPS "${name}")
  set_property(GLOBAL PROPERTY _SUPERNINJA_${name}_CONFIGURE_COMMAND "${ARG_CONFIGURE_COMMAND}")
  
  if(ARG_NINJA_FILE)
    set_property(GLOBAL PROPERTY _SUPERNINJA_${name}_NINJA_FILE "${ARG_NINJA_FILE}")
  else()
    # TODO: Set auto-calculated ninja file location
    message(STATUS "Superninja: Would auto-calculate NINJA_FILE for ${name}")
  endif()
  
  # Remove our custom args and forward to FetchContent_Declare
  set(fc_args ${ARGN})
  list(REMOVE_ITEM fc_args CONFIGURE_COMMAND NINJA_FILE ${ARG_CONFIGURE_COMMAND} ${ARG_NINJA_FILE})
  FetchContent_Declare(${name} ${fc_args})
endfunction()

function(Superninja_Populate name)
  # Verify declared
  get_property(declared_deps GLOBAL PROPERTY _SUPERNINJA_DECLARED_DEPS)
  if(NOT name IN_LIST declared_deps)
    message(FATAL_ERROR "Superninja_Populate: '${name}' not declared")
  endif()

  # Delegate to FetchContent
  FetchContent_Populate(${name})
endfunction()

function(Superninja_MakeAvailable)
  foreach(name ${ARGV})
    # Verify declared
    get_property(declared_deps GLOBAL PROPERTY _SUPERNINJA_DECLARED_DEPS)
    if(NOT name IN_LIST declared_deps)
      message(FATAL_ERROR "Superninja_MakeAvailable: '${name}' not declared")
    endif()

    # Populate if needed
    FetchContent_GetProperties(${name})
    if(NOT ${name}_POPULATED)
      FetchContent_Populate(${name})
    endif()

    # Get metadata
    get_property(configure_cmd GLOBAL PROPERTY _SUPERNINJA_${name}_CONFIGURE_COMMAND)
    get_property(ninja_file GLOBAL PROPERTY _SUPERNINJA_${name}_NINJA_FILE)
    
    # TODO: Perform @VAR@ variable expansion on configure_cmd
    # TODO: Set up @SUPERNINJA_*@ variables based on calculated directories
    
    # Configure if needed
    if(SUPERNINJA_FORCE_RECONFIGURE OR NOT EXISTS "${ninja_file}")
      # TODO: Execute expanded configure command via execute_process
      # TODO: Validate ninja file was created
      message(STATUS "Superninja: Would configure ${name}")
      message(STATUS "  Command: ${configure_cmd}")
      message(STATUS "  Expected ninja file: ${ninja_file}")
    endif()
    
    # Register for integration
    set_property(GLOBAL APPEND PROPERTY _SUPERNINJA_AVAILABLE_DEPS "${name}")
  endforeach()
endfunction()

function(Superninja_Finalize)
  set(options)
  set(oneValueArgs OUTPUT)
  set(multiValueArgs DEPENDENCIES)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT ARG_OUTPUT)
    message(FATAL_ERROR "Superninja_Finalize: OUTPUT is required")
  endif()

  get_property(available_deps GLOBAL PROPERTY _SUPERNINJA_AVAILABLE_DEPS)

  # TODO: Generate master ninja file with subninja directives
  # TODO: Parse DEPENDENCIES and create phony targets
  # TODO: Include mosmess's own ninja file
  
  message(STATUS "Superninja: Would generate ${ARG_OUTPUT}")
  message(STATUS "  Available dependencies: ${available_deps}")
  if(ARG_DEPENDENCIES)
    message(STATUS "  Dependencies: ${ARG_DEPENDENCIES}")
  endif()
endfunction()