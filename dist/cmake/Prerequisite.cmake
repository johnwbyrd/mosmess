# CMake Prerequisites System
#
# The prerequisites system lets you build external dependencies during CMake's 
# configuration phase, before the project() command runs. This is crucial when 
# you need to build the very tools that CMake is about to look for.

#[=======================================================================[.rst:
Prerequisite
------------

The prerequisites system lets you build external dependencies during CMake's
configuration phase, before the ``project()`` command runs. This is crucial
when you need to build the very tools that CMake is about to look for.

The prerequisites system breaks this deadlock. It can build your dependencies
immediately during configuration (so they're ready when ``project()`` runs), 
and it also creates normal CMake targets for incremental rebuilds later.

Functions
^^^^^^^^^

.. command:: Prerequisite_Add

  Main function to define a prerequisite.

  .. code-block:: cmake

    Prerequisite_Add(<name> [options...])

  **Note:** For all step command options (*_COMMAND), if no command is specified, 
  that step performs no action. Prerequisites are diverse external projects that 
  require explicit commands for each step. Command and argument options support 
  ``@VARIABLE@`` substitution using the variables listed below.

  **Options:**

  ``DEPENDS <prereqs...>``
    Names of other prerequisites that must be built first. The DEPENDS option 
    works differently at configure time versus build time. At configure time, 
    it does NOT enforce dependencies -- prerequisites execute in the order they 
    appear in your CMakeLists.txt regardless of DEPENDS declarations. At build 
    time, it creates proper target dependencies so this prerequisite's targets 
    depend on the dependency's targets. To ensure dependencies are built at 
    configure time, you must list prerequisites in dependency order in your 
    CMakeLists.txt.

  **Directory Options:**

  ``PREFIX <dir>``
    Root directory for this prerequisite

  ``SOURCE_DIR <dir>``
    Source directory (can be pre-existing)

  ``BINARY_DIR <dir>``
    Build directory

  ``INSTALL_DIR <dir>``
    Installation directory

  ``STAMP_DIR <dir>``
    Directory for stamp files

  ``LOG_DIR <dir>``
    Directory for log files (defaults to STAMP_DIR if not specified)

  **Download Step Options:**

  Git-based downloads:

  ``GIT_REPOSITORY <url>``
    Git repository URL

  ``GIT_TAG <tag>``
    Git branch, tag, or commit

  ``GIT_SHALLOW``
    Perform shallow clone

  URL-based downloads:

  ``URL <url>``
    Download URL for archives

  ``URL_HASH <algo>=<hash>``
    Hash verification

  Custom downloads:

  ``DOWNLOAD_COMMAND <cmd...>``
    Custom download command

  ``DOWNLOAD_NO_EXTRACT``
    Don't extract downloaded archives

  **Note:** Git-based and URL-based options are mutually exclusive.

  **Update Step Options:**

  ``UPDATE_COMMAND <cmd...>``
    Custom update command

  ``UPDATE_DISCONNECTED``
    Skip update step

  **Configure Step Options:**

  ``CONFIGURE_COMMAND <cmd...>``
    Configure command

  **Build Step Options:**

  ``BUILD_COMMAND <cmd...>``
    Build command

  ``BUILD_IN_SOURCE``
    Build in source directory

  **Install Step Options:**

  ``INSTALL_COMMAND <cmd...>``
    Install command

  **Test Step Options:**

  ``TEST_COMMAND <cmd...>``
    Test command

  **Command Variable Substitution:**

  All command arguments support ``@VARIABLE@`` substitution:

  * ``@PREREQUISITE_NAME@`` - The prerequisite name
  * ``@PREREQUISITE_PREFIX@`` - The prefix directory  
  * ``@PREREQUISITE_SOURCE_DIR@`` - Source directory path
  * ``@PREREQUISITE_BINARY_DIR@`` - Build directory path
  * ``@PREREQUISITE_INSTALL_DIR@`` - Install directory path
  * ``@PREREQUISITE_STAMP_DIR@`` - Stamp directory path
  * ``@PREREQUISITE_LOG_DIR@`` - Log directory path

  **Logging Options:**

  ``LOG_DOWNLOAD <bool>``
    When true, redirect download step output to log files instead of console

  ``LOG_UPDATE <bool>``
    When true, redirect update step output to log files instead of console

  ``LOG_CONFIGURE <bool>``
    When true, redirect configure step output to log files instead of console

  ``LOG_BUILD <bool>``
    When true, redirect build step output to log files instead of console

  ``LOG_INSTALL <bool>``
    When true, redirect install step output to log files instead of console

  ``LOG_TEST <bool>``
    When true, redirect test step output to log files instead of console

  ``LOG_OUTPUT_ON_FAILURE <bool>``
    When true, only show captured log output if the step fails

  **Normal behavior**: Step output appears directly in CMake configure log or 
  build output. **With LOG_* true**: Step output is captured to automatically 
  named files like ``<name>-build-out.log`` in LOG_DIR (or STAMP_DIR if LOG_DIR 
  not specified), console shows only summary messages.

  **File Dependency Options:**

  These options enable intelligent rebuild behavior by tracking changes to 
  specific files within a prerequisite's source tree, rather than relying 
  solely on timestamp-based stamp files.

  ``DOWNLOAD_DEPENDS <args...>``
    File dependency arguments for download step

  ``UPDATE_DEPENDS <args...>``
    File dependency arguments for update step

  ``CONFIGURE_DEPENDS <args...>``
    File dependency arguments for configure step

  ``BUILD_DEPENDS <args...>``
    File dependency arguments for build step

  ``INSTALL_DEPENDS <args...>``
    File dependency arguments for install step

  ``TEST_DEPENDS <args...>``
    File dependency arguments for test step

  **Purpose:** File dependency tracking allows prerequisites to rebuild only 
  when their internal dependencies have actually changed. This provides more 
  granular and efficient rebuild behavior than simple timestamp checking.

  **File Dependency Behavior:** When you specify file dependencies for a step, 
  you provide glob patterns that tell the system which files to track. The first 
  argument should typically be ``GLOB`` or ``GLOB_RECURSE``, followed by the 
  actual glob patterns with variable substitution applied. File dependencies 
  completely replace stamp-based tracking for that step -- the step will run 
  when any dependency file is newer than the step's outputs, or when outputs 
  are missing, using CMake's normal dependency resolution.

  **Control Options:**

  ``<STEP>_ALWAYS <bool>``
    Whether to always run specific step (e.g., ``CONFIGURE_ALWAYS``).  A true
    value forces the step to run every time, regardless of file dependencies.

.. command:: Prerequisite_Add_Step

  Add a custom step to a prerequisite.

  .. code-block:: cmake

    Prerequisite_Add_Step(<name> <step> [options...])

  **Options:**

  ``COMMAND <cmd...>``
    Command to execute

  ``DEPENDEES <steps...>``
    Steps this depends on

  ``DEPENDERS <steps...>``
    Steps that depend on this

  ``WORKING_DIRECTORY <dir>``
    Working directory for command

  ``ALWAYS``
    Always run this step

.. command:: Prerequisite_Get_Property

  Retrieve properties from a prerequisite.

  .. code-block:: cmake

    Prerequisite_Get_Property(<name> <property> <output_variable>)

  **Properties:** All options from ``Prerequisite_Add`` can be retrieved as properties.

.. command:: Prerequisite_Force_Step

  Force execution of a step and all subsequent steps.

  .. code-block:: cmake

    Prerequisite_Force_Step(<name> <step>)

  This function is typically called by phony targets to force rebuilds.

.. command:: Prerequisite_Step_Current

  Check if a step is up-to-date.

  .. code-block:: cmake

    Prerequisite_Step_Current(<name> <step> <output_variable>)

  Sets output variable to TRUE if step is current, FALSE if it needs to run.

#]=======================================================================]

# Implementation

# Internal step list - defines the order and names of all prerequisite steps
set(_PREREQUISITE_STEPS DOWNLOAD UPDATE CONFIGURE BUILD INSTALL TEST)

# Internal substitution variables - defines all @PREREQUISITE_*@ variable names
set(_PREREQUISITE_SUBSTITUTION_VARS NAME PREFIX SOURCE_DIR BINARY_DIR INSTALL_DIR STAMP_DIR LOG_DIR)

# Map each step to a new string by applying prefix and suffix
# Transforms each step in _PREREQUISITE_STEPS using the pattern: prefix + step + suffix
# Example: _Prerequisite_Map_Steps("LOG_" "" result) -> LOG_DOWNLOAD, LOG_UPDATE, etc.
# Example: _Prerequisite_Map_Steps("" "_COMMAND" result) -> DOWNLOAD_COMMAND, UPDATE_COMMAND, etc.
function(_Prerequisite_Map_Steps prefix suffix out_var)
  set(result "")
  foreach(step ${_PREREQUISITE_STEPS})
    list(APPEND result "${prefix}${step}${suffix}")
  endforeach()
  set(${out_var} ${result} PARENT_SCOPE)
endfunction()

# Debug function to dump all prerequisite properties for a given name
# WARNING: This function is for debugging purposes only
# Since CMake doesn't provide a way to enumerate custom global properties,
# this function checks all known prerequisite property names
function(_Prerequisite_Debug_Dump name)
  message(STATUS "=== Prerequisite Properties for ${name} ===")
  
  # Generate lists of all possible property names
  _Prerequisite_Map_Steps("" "_ALWAYS" step_always_opts)
  _Prerequisite_Map_Steps("LOG_" "" step_log_opts)
  _Prerequisite_Map_Steps("" "_COMMAND" step_command_opts)
  _Prerequisite_Map_Steps("" "_DEPENDS" step_depends_opts)
  
  # All possible property names
  set(all_properties
    # Directory properties
    PREFIX SOURCE_DIR BINARY_DIR INSTALL_DIR STAMP_DIR LOG_DIR
    # Git/URL properties  
    GIT_REPOSITORY GIT_TAG URL URL_HASH
    # Boolean flags
    GIT_SHALLOW DOWNLOAD_NO_EXTRACT UPDATE_DISCONNECTED BUILD_IN_SOURCE
    # Other options
    LOG_OUTPUT_ON_FAILURE DEPENDS
    # Generated step-specific properties
    ${step_always_opts} ${step_log_opts} ${step_command_opts} ${step_depends_opts}
  )
  
  # Check each property and display if set
  foreach(prop ${all_properties})
    get_property(value GLOBAL PROPERTY _PREREQUISITE_${name}_${prop})
    get_property(is_set GLOBAL PROPERTY _PREREQUISITE_${name}_${prop} SET)
    if(is_set)
      message(STATUS "  ${prop} = ${value}")
    endif()
  endforeach()
  
  message(STATUS "=== End Properties for ${name} ===")
endfunction()

# Check if we're running at configure time (before project())
# Returns TRUE if CMAKE_PROJECT_NAME is not defined (configure time)
# Returns FALSE if CMAKE_PROJECT_NAME is defined (build time)
function(_Prerequisite_Is_Configure_Time out_var)
  if(NOT DEFINED CMAKE_PROJECT_NAME)
    set(${out_var} TRUE PARENT_SCOPE)
  else()
    set(${out_var} FALSE PARENT_SCOPE)
  endif()
endfunction()

# Parse all arguments using cmake_parse_arguments
# - Extract options like IMMEDIATE, BUILD_ALWAYS
# - Extract single-value args like PREFIX, SOURCE_DIR, etc.
# - Extract multi-value args like DEPENDS, COMMANDS, and all step-specific options
# - Store all parsed arguments as global properties using pattern:
#   _PREREQUISITE_${name}_${property_name}
# - This allows other helper functions to retrieve arguments using
#   get_property(GLOBAL) without needing PARENT_SCOPE variable passing
# - Follows the same approach as ExternalProject and FetchContent
function(_Prerequisite_Parse_Arguments name)
  # Generate step-specific argument names
  _Prerequisite_Map_Steps("" "_ALWAYS" step_always_opts)
  _Prerequisite_Map_Steps("LOG_" "" step_log_opts)
  _Prerequisite_Map_Steps("" "_COMMAND" step_command_opts)
  _Prerequisite_Map_Steps("" "_DEPENDS" step_depends_opts)
  
  # Set up argument categories for cmake_parse_arguments
  set(options 
    GIT_SHALLOW DOWNLOAD_NO_EXTRACT UPDATE_DISCONNECTED BUILD_IN_SOURCE
  )
  
  set(oneValueArgs
    PREFIX SOURCE_DIR BINARY_DIR INSTALL_DIR STAMP_DIR LOG_DIR
    GIT_REPOSITORY GIT_TAG URL URL_HASH LOG_OUTPUT_ON_FAILURE
    ${step_log_opts}
    ${step_always_opts}
  )
  
  set(multiValueArgs
    DEPENDS
    ${step_command_opts}
    ${step_depends_opts}
  )
  
  # Parse arguments starting from index 1 (skip the name parameter)
  cmake_parse_arguments(PARSE_ARGV 1 PA "${options}" "${oneValueArgs}" "${multiValueArgs}")
  
  # Store each parsed argument as a global property
  foreach(option ${options})
    if(PA_${option})
      set_property(GLOBAL PROPERTY _PREREQUISITE_${name}_${option} TRUE)
    endif()
  endforeach()
  
  foreach(arg ${oneValueArgs})
    if(DEFINED PA_${arg})
      set_property(GLOBAL PROPERTY _PREREQUISITE_${name}_${arg} "${PA_${arg}}")
    endif()
  endforeach()
  
  foreach(arg ${multiValueArgs})
    if(DEFINED PA_${arg})
      set_property(GLOBAL PROPERTY _PREREQUISITE_${name}_${arg} "${PA_${arg}}")
    endif()
  endforeach()
  
  # Validate argument combinations
  get_property(has_git GLOBAL PROPERTY _PREREQUISITE_${name}_GIT_REPOSITORY SET)
  get_property(has_url GLOBAL PROPERTY _PREREQUISITE_${name}_URL SET)
  if(has_git AND has_url)
    message(FATAL_ERROR "Prerequisite ${name}: GIT_REPOSITORY and URL are mutually exclusive")
  endif()
endfunction()

# Set up default directory structure if not explicitly provided
# - Default PREFIX based on name
# - Default SOURCE_DIR, BINARY_DIR, STAMP_DIR, etc. based on PREFIX
function(_Prerequisite_Setup_Directories name)
  # Set up directory defaults - skip NAME since it's not a directory
  set(directory_vars PREFIX SOURCE_DIR BINARY_DIR INSTALL_DIR STAMP_DIR LOG_DIR)
  
  # First pass: compute defaults
  foreach(var ${directory_vars})
    get_property(user_value GLOBAL PROPERTY _PREREQUISITE_${name}_${var})
    
    if(user_value)
      set(${var} "${user_value}")
    else()
      # Compute defaults based on variable type
      if(var STREQUAL "PREFIX")
        set(${var} "${CMAKE_CURRENT_BINARY_DIR}/${name}-prefix")
      elseif(var STREQUAL "SOURCE_DIR")
        set(${var} "${PREFIX}/src/${name}")
      elseif(var STREQUAL "BINARY_DIR")
        set(${var} "${PREFIX}/src/${name}-build")
      elseif(var STREQUAL "INSTALL_DIR")
        set(${var} "${PREFIX}")
      elseif(var STREQUAL "STAMP_DIR")
        set(${var} "${PREFIX}/src/${name}-stamp")
      elseif(var STREQUAL "LOG_DIR")
        set(${var} "${STAMP_DIR}")
      endif()
    endif()
  endforeach()
  
  # Second pass: store final values and create directories
  foreach(var ${directory_vars})
    set_property(GLOBAL PROPERTY _PREREQUISITE_${name}_${var} "${${var}}")
    file(MAKE_DIRECTORY "${${var}}")
  endforeach()
endfunction()


# Process each step in order (DOWNLOAD, UPDATE, CONFIGURE, BUILD, INSTALL, TEST)
function(_Prerequisite_Process_Steps name)
  # Retrieve configure-time flag and necessary properties
  get_property(is_configure_time GLOBAL PROPERTY _PREREQUISITE_${name}_IS_CONFIGURE_TIME)
  get_property(prerequisite_depends GLOBAL PROPERTY _PREREQUISITE_${name}_DEPENDS)
  
  # Get properties for variable substitution
  foreach(var ${_PREREQUISITE_SUBSTITUTION_VARS})
    if(var STREQUAL "NAME")
      set(${var} "${name}")
    else()
      get_property(${var} GLOBAL PROPERTY _PREREQUISITE_${name}_${var})
    endif()
  endforeach()
  
  set(previous_stamp_file "")
  
  # Process each step in order
  foreach(step ${_PREREQUISITE_STEPS})
    # Step 1: Check if this step has commands defined
    get_property(step_command GLOBAL PROPERTY _PREREQUISITE_${name}_${step}_COMMAND)
    if(NOT step_command)
      continue()
    endif()
    
    # Set up paths for this step
    set(stamp_file "${STAMP_DIR}/${name}-${step}")
    
    # Step 3: Immediate execution if at configure time
    if(is_configure_time)
      set(needs_to_run FALSE)
      
      if(uses_file_deps)
        # TODO: Compare file timestamps - for now, always run
        set(needs_to_run TRUE)
      else()
        # Check if stamp file exists
        if(NOT EXISTS "${stamp_file}")
          set(needs_to_run TRUE)
        endif()
      endif()
      
      if(needs_to_run)
        # Perform variable substitution
        set(substituted_command "")
        foreach(cmd_part ${step_command})
          foreach(var ${_PREREQUISITE_SUBSTITUTION_VARS})
            string(REPLACE "@PREREQUISITE_${var}@" "${${var}}" cmd_part "${cmd_part}")
          endforeach()
          list(APPEND substituted_command "${cmd_part}")
        endforeach()
        
        message(STATUS "Prerequisite ${name}: Running ${step} step immediately")
        execute_process(
          COMMAND ${substituted_command}
          WORKING_DIRECTORY "${binary_dir}"
          RESULT_VARIABLE result
        )
        
        if(NOT result EQUAL 0)
          # Clean up stamps for this and subsequent steps
          foreach(cleanup_step ${_PREREQUISITE_STEPS})
            file(REMOVE "${stamp_dir}/${name}-${cleanup_step}")
            if(cleanup_step STREQUAL step)
              break()
            endif()
          endforeach()
          message(FATAL_ERROR "Prerequisite ${name}: ${step} step failed")
        endif()
        
        # Create stamp file
        file(TOUCH "${stamp_file}")
      endif()
    endif()
    
    # Step 4: Create build-time targets
    string(TOLOWER "${step}" step_lower)
    
    if(uses_file_deps)
      # File dependency tracking - no stamp files
      set(step_deps "")
      if(previous_stamp_file)
        list(APPEND step_deps "${previous_stamp_file}")
      endif()
      # TODO: Process file dependency patterns properly
      list(APPEND step_deps ${step_depends})
      
      # Create custom target that runs the command directly
      add_custom_target(${name}-${step_lower}
        COMMAND ${step_command}
        DEPENDS ${step_deps}
        WORKING_DIRECTORY "${binary_dir}"
        COMMENT "Prerequisite ${name}: Running ${step} step"
      )
      
      # No stamp file is created or used for this step
      set(previous_stamp_file "")
    else()
      # Stamp-based tracking
      set(step_deps "")
      if(previous_stamp_file)
        list(APPEND step_deps "${previous_stamp_file}")
      endif()
      
      # Create the custom command that produces a stamp file
      add_custom_command(
        OUTPUT "${stamp_file}"
        COMMAND ${step_command}
        COMMAND ${CMAKE_COMMAND} -E touch "${stamp_file}"
        DEPENDS ${step_deps}
        WORKING_DIRECTORY "${binary_dir}"
        COMMENT "Prerequisite ${name}: Running ${step} step"
      )
      
      # Create named target that depends on the stamp file
      add_custom_target(${name}-${step_lower}
        DEPENDS "${stamp_file}"
      )
      
      # Update previous stamp for next iteration
      set(previous_stamp_file "${stamp_file}")
    endif()
    
    # Create force target
    if(uses_file_deps)
      # For file dependency tracking, force target just runs the step
      add_custom_target(${name}-force-${step_lower}
        COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target ${name}-${step_lower}
        COMMENT "Prerequisite ${name}: Force ${step} step"
      )
    else()
      # For stamp tracking, force target removes stamp then runs
      add_custom_target(${name}-force-${step_lower}
        COMMAND ${CMAKE_COMMAND} -E remove "${stamp_file}"
        COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target ${name}-${step_lower}
        COMMENT "Prerequisite ${name}: Force ${step} step"
      )
    endif()
  endforeach()
  
  # Handle prerequisite-level dependencies
  if(prerequisite_depends)
    foreach(dep_prereq ${prerequisite_depends})
      foreach(step ${_PREREQUISITE_STEPS})
        get_property(step_command GLOBAL PROPERTY _PREREQUISITE_${name}_${step}_COMMAND)
        if(step_command)
          string(TOLOWER "${step}" step_lower)
          add_dependencies(${name}-${step_lower} ${dep_prereq}-${step_lower})
        endif()
      endforeach()
    endforeach()
  endif()
endfunction()

# Set up any final properties or variables needed
function(_Prerequisite_Finalize name)
endfunction()

function(Prerequisite_Add name)
  _Prerequisite_Is_Configure_Time(is_configure_time)
  set_property(GLOBAL PROPERTY _PREREQUISITE_${name}_IS_CONFIGURE_TIME "${is_configure_time}")
  _Prerequisite_Parse_Arguments(${name} ${ARGN})
  _Prerequisite_Setup_Directories(${name})
  _Prerequisite_Process_Steps(${name})
  _Prerequisite_Finalize(${name})
  
  message(STATUS "Prerequisite_Add(${name}) - stub implementation")
endfunction()

function(Prerequisite_Add_Step name step)
  message(STATUS "Prerequisite_Add_Step(${name} ${step}) - stub implementation") 
  # TODO: Implement custom step addition
endfunction()

function(Prerequisite_Get_Property name property output_variable)
  # Retrieve properties from a prerequisite
  # - Uses global properties stored with pattern _PREREQUISITE_${name}_${property_name}
  # - This matches the storage approach used by _Prerequisite_Parse_Arguments
  # - Follows the same design as ExternalProject_Get_Property and FetchContent
  # - All options from Prerequisite_Add can be retrieved this way
  get_property(value GLOBAL PROPERTY _PREREQUISITE_${name}_${property})
  set(${output_variable} "${value}" PARENT_SCOPE)
endfunction()

function(Prerequisite_Force_Step name step)
  message(STATUS "Prerequisite_Force_Step(${name} ${step}) - stub implementation")
  # TODO: Implement forced step execution
endfunction()

function(Prerequisite_Step_Current name step output_variable)
  message(STATUS "Prerequisite_Step_Current(${name} ${step}) - stub implementation")
  # TODO: Implement step currency checking
  set(${output_variable} FALSE PARENT_SCOPE)
endfunction()