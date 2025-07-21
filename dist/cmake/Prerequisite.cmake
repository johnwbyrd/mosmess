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

  ``BUILD_ALWAYS``
    Always rebuild regardless of stamps

  ``<STEP>_ALWAYS``
    Always run specific step (e.g., ``CONFIGURE_ALWAYS``)

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

function(Prerequisite_Add name)
  message(STATUS "Prerequisite_Add(${name}) - stub implementation")
  # TODO: Implement prerequisite creation and dual execution model
endfunction()

function(Prerequisite_Add_Step name step)
  message(STATUS "Prerequisite_Add_Step(${name} ${step}) - stub implementation") 
  # TODO: Implement custom step addition
endfunction()

function(Prerequisite_Get_Property name property output_variable)
  message(STATUS "Prerequisite_Get_Property(${name} ${property}) - stub implementation")
  # TODO: Implement property retrieval
  set(${output_variable} "" PARENT_SCOPE)
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