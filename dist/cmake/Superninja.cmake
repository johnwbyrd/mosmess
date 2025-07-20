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
  # Declare a dependency with source location and build configuration.
  #
  # Superninja_Declare(<name>
  #   [GIT_REPOSITORY <repository>]
  #   [GIT_TAG <tag>]
  #   [... all FetchContent_Declare arguments ...]
  #   CONFIGURE_COMMAND <command>
  #   [NINJA_FILE <path>]
  # )
  #
  # This function accepts all parameters that FetchContent_Declare accepts, plus superninja-specific
  # parameters. It filters out the superninja parameters (CONFIGURE_COMMAND, NINJA_FILE) and forwards
  # all other parameters directly to FetchContent_Declare unchanged.
  #
  # Superninja-specific arguments:
  #   CONFIGURE_COMMAND - Command to run to configure the dependency and generate build.ninja
  #   NINJA_FILE - Optional explicit path where build.ninja will be created
  #
  # FetchContent arguments:
  #   All FetchContent_Declare parameters are accepted and forwarded:
  #   GIT_REPOSITORY, GIT_TAG, URL, URL_HASH, SOURCE_DIR, etc.
  #
  # The CONFIGURE_COMMAND will be executed by Superninja_Populate or Superninja_MakeAvailable
  # to generate the build.ninja file that will be included via subninja directive.
  
  # TODO: Implement Superninja_Declare
  message(STATUS "Superninja_Declare: Stub for ${name}")
endfunction()

function(Superninja_Populate name)
  # Download sources and run configure step for a declared dependency.
  #
  # Superninja_Populate(<name>)
  #
  # This function accepts all parameters that FetchContent_Populate accepts and forwards
  # them directly to FetchContent_Populate unchanged. It then adds the superninja configure
  # step to generate the build.ninja file.
  #
  # Arguments:
  #   All FetchContent_Populate parameters are accepted and forwarded unchanged.
  #   Typically just the dependency name, but can include any FetchContent_Populate options.
  #
  # Behavior:
  # 1. Forwards all parameters to FetchContent_Populate to download sources
  # 2. Executes the stored CONFIGURE_COMMAND to generate build.ninja
  # 3. The ninja file location is either user-specified (NINJA_FILE) or automatically calculated
  #
  # The dependency must have been previously declared with Superninja_Declare().
  # After this function completes, the build.ninja file will exist and be ready for
  # inclusion in Superninja_Finalize().
  
  # TODO: Implement Superninja_Populate
  message(STATUS "Superninja_Populate: Stub for ${name}")
endfunction()

function(Superninja_MakeAvailable)
  # Download sources and run configure step for multiple dependencies.
  #
  # Superninja_MakeAvailable(<name1> [<name2> ...])
  #
  # This function accepts all parameters that FetchContent_MakeAvailable accepts and forwards
  # them directly to FetchContent_MakeAvailable unchanged. It then adds the superninja configure
  # step for each dependency to generate build.ninja files.
  #
  # Arguments:
  #   All FetchContent_MakeAvailable parameters are accepted and forwarded unchanged.
  #   Typically dependency names, but can include any FetchContent_MakeAvailable options.
  #
  # Behavior:
  # 1. Forwards all parameters to FetchContent_MakeAvailable to download sources
  # 2. For each dependency, executes the stored CONFIGURE_COMMAND to generate build.ninja
  # 3. Ninja file locations are automatically calculated (not user-specified)
  # 4. Registers dependencies as available for Superninja_Finalize()
  #
  # All dependencies must have been previously declared with Superninja_Declare().
  # After this function completes, all build.ninja files will exist and be ready for
  # inclusion in Superninja_Finalize().
  
  # TODO: Implement Superninja_MakeAvailable  
  message(STATUS "Superninja_MakeAvailable: Stub for ${ARGV}")
endfunction()

function(Superninja_Finalize)
  # Generate master ninja file that includes all dependency ninja files via subninja.
  #
  # Superninja_Finalize(
  #   OUTPUT <master-ninja-file>
  #   [DEPENDENCIES <target> DEPENDS_ON <dependency> ...]
  # )
  #
  # This function creates a master ninja file that unifies all dependency build graphs
  # into a single ninja execution context, enabling cross-project incremental builds
  # and dependency tracking.
  #
  # Arguments:
  #   OUTPUT - Path where the master ninja file will be created
  #   DEPENDENCIES - Optional cross-project dependency specifications
  #                 Format: target DEPENDS_ON dependency [target DEPENDS_ON dependency ...]
  #
  # Behavior:
  # 1. Creates master ninja file with subninja directives for all available dependencies
  # 2. Includes main project's ninja file if it exists
  # 3. Generates phony targets for cross-project dependencies
  # 4. All paths are resolved relative to the master ninja file location
  #
  # The resulting master ninja file can be executed with ninja to build all projects
  # with optimal scheduling and dependency tracking across project boundaries.
  
  # TODO: Implement Superninja_Finalize
  message(STATUS "Superninja_Finalize: Stub")
endfunction()