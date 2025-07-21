# Prerequisites System

## Overview

The Prerequisites system provides a unified mechanism to download, build, and install external dependencies that can execute both during CMake configuration and as part of the build process. This dual-mode system is designed to handle complex dependency scenarios, particularly building compilers and toolchains that must exist before the main project can even be configured.

The design mirrors CMake's ExternalProject module but adds the critical capability of immediate execution during configuration, while still providing proper build-time dependency tracking.

## The Problem

Traditional CMake projects assume that compilers and essential libraries already exist when configuration begins. The `project()` statement triggers compiler detection, feature tests, and library searches. But this creates ordering challenges for certain types of projects:

1. **Cross-compilation toolchains**: When developing for embedded systems or alternative architectures, you often need to build the cross-compiler as part of your project setup.

2. **Custom standard libraries**: Projects may need to build their own C library or runtime using the same compiler that will build the main project.

3. **Bootstrapped environments**: Some projects need to build multiple interdependent components where each component requires the previous one to exist before it can be configured.

In these scenarios, the standard CMake workflow breaks down because:
- The `project()` command needs a working compiler, but that compiler doesn't exist yet
- FetchContent and ExternalProject run too late - after compiler detection
- You need the compiler to build libraries, but those libraries must exist before the main project configuration

## The Solution

The Prerequisites system addresses these ordering issues with a dual-mode approach:

1. **Configuration Mode**: Can run before `project()` to bootstrap compilers and tools
2. **Build Mode**: Creates proper CMake targets for dependency tracking and incremental builds

This unified approach enables:
- Building cross-compilers before CMake needs to detect them
- Creating proper dependency chains for incremental rebuilds
- Integrating prerequisite builds with the main project's dependency graph
- Supporting both bootstrap and development workflows

Unlike FetchContent or ExternalProject, Prerequisites can execute immediately during configuration while still providing build-time dependency tracking.

## Dual Execution Model

The Prerequisites system supports two execution modes:

### 1. Immediate Execution

When stamps don't exist or when forced, prerequisites execute immediately:
- Uses `execute_process()` to run commands during configuration
- Essential for bootstrapping compilers before `project()`
- Blocks until completion
- Creates stamps to prevent unnecessary re-execution

### 2. Target-Based Execution

The system always creates CMake targets for build-time dependency tracking:
- Creates targets like `llvm-mos-build`, `llvm-mos-install`, etc.
- Uses `add_custom_command()` chains with stamp files as outputs
- Integrates with CMake's normal dependency system
- Enables incremental rebuilds and parallel builds

### How It Works

When you call `Prerequisite_Add()`:
1. Checks if steps need to run (missing stamps or forced execution)
2. If needed and called before `project()`: Executes immediately via `execute_process()`
3. Always creates build-time targets using `add_custom_command()` that:
   - Depend on the previous step's stamp file
   - Execute the step's command directly
   - Create their own stamp file upon successful completion
4. Subsequent project targets can depend on these prerequisite targets

### Implementation Details

Both execution modes share the same underlying step logic:

**Immediate Execution (Configuration Time):**
- Triggered when stamps are missing or forced
- Uses `execute_process()` to run commands
- CMake code checks return status and creates stamps
- Blocking - configuration waits for completion
- Essential for bootstrapping scenarios

**Target-Based Execution (Build Time):**
- Always created via `add_custom_command()`
- Stamp files serve as OUTPUT dependencies
- Commands run directly in the build tool
- Non-blocking during configuration
- Provides proper incremental build support

The beauty of this design is that the same prerequisites can bootstrap a toolchain from scratch AND integrate seamlessly with incremental development workflows.

### Performance Implications

- **First Run**: Initial configuration may be slow if prerequisites need to be built
- **Incremental**: Subsequent configurations are fast - stamps prevent re-execution
- **Build Time**: Normal incremental build performance via standard dependency tracking
- **Development**: Changes to prerequisites trigger minimal rebuilds

## Core Concepts

### Step-Based Architecture

Prerequisites are built through a series of ordered steps:

1. **download** - Obtain source code
2. **update** - Update source code to latest version
3. **configure** - Configure the build system
4. **build** - Compile the software
5. **install** - Install to destination
6. **test** - Run tests (optional)

### Step Execution Rules

When a step is requested, that step and all subsequent steps are executed:

- Requesting "download" → runs download, update, configure, build, install, test
- Requesting "configure" → runs configure, build, install, test  
- Requesting "build" → runs build, install, test
- Requesting "install" → runs install, test
- Requesting "test" → runs only test

This ensures consistency - if you rebuild, you must reinstall and retest.

### Stamp Files

Each step creates a stamp file upon successful completion. These stamps serve dual purposes:

**At Configure Time:**
- Track whether a step has been completed
- Prevent re-running expensive operations
- Store metadata about when/how step was executed

**At Build Time:**
- Act as OUTPUT files for `add_custom_command()`
- Create dependency chains between steps
- Trigger rebuilds when missing

**Stamp Creation:**
- Configure time: Created by CMake code after successful `execute_process()`
- Build time: Created by `${CMAKE_COMMAND} -E touch` after successful command
- Both modes create identical stamp files

**Failure Handling:**
If a step fails, all subsequent step stamps are invalidated and removed. This ensures that later steps will re-run after fixing the failure.

### Directory Layout

Prerequisites use a directory structure similar to ExternalProject:

- `PREFIX/src/<name>` - Source directory
- `PREFIX/src/<name>-build` - Binary/build directory  
- `PREFIX/src/<name>-stamp` - Stamp files
- `PREFIX/src/<name>-log` - Log files
- `PREFIX` - Install directory (shared by all prerequisites)

## Function Reference

### Prerequisite_Add

Main function to define a prerequisite.

**Synopsis:**
```
Prerequisite_Add(<name> [options...])
```

**Options:**

#### Dependency Options
- `DEPENDS <prereqs...>` - Names of other prerequisites that must be built first.
  - **Configure time**: Does NOT enforce dependencies - prerequisites execute in the order they appear in your CMakeLists.txt
  - **Build time**: Creates proper target dependencies so this prerequisite's targets depend on the dependency's targets
  - Example: If A depends on B, then A-install will depend on B-install
  - **Important**: To ensure dependencies are built at configure time, list them in dependency order in your CMakeLists.txt

#### Directory Options
- `PREFIX <dir>` - Root directory for this prerequisite
- `SOURCE_DIR <dir>` - Source directory (can be pre-existing)
- `BINARY_DIR <dir>` - Build directory
- `INSTALL_DIR <dir>` - Installation directory
- `STAMP_DIR <dir>` - Directory for stamp files
- `LOG_DIR <dir>` - Directory for log files

#### Download Step Options
- `GIT_REPOSITORY <url>` - Git repository URL
- `GIT_TAG <tag>` - Git branch, tag, or commit
- `GIT_SHALLOW` - Perform shallow clone
- `URL <url>` - Download URL for archives
- `URL_HASH <algo>=<hash>` - Hash verification
- `DOWNLOAD_COMMAND <cmd...>` - Custom download command (supports variable substitution)
- `DOWNLOAD_NO_EXTRACT` - Don't extract downloaded archives

#### Update Step Options
- `UPDATE_COMMAND <cmd...>` - Custom update command (supports variable substitution)
- `UPDATE_DISCONNECTED` - Skip update step

#### Configure Step Options
- `CONFIGURE_COMMAND <cmd...>` - Configure command (supports variable substitution)
- `CMAKE_COMMAND <cmd>` - CMake executable to use
- `CMAKE_ARGS <args...>` - Arguments for CMake configure (supports variable substitution)
- `CMAKE_CACHE_ARGS <args...>` - Initial cache values (supports variable substitution)

#### Build Step Options
- `BUILD_COMMAND <cmd...>` - Build command (supports variable substitution)
- `BUILD_IN_SOURCE` - Build in source directory

#### Install Step Options
- `INSTALL_COMMAND <cmd...>` - Install command (supports variable substitution)

#### Test Step Options
- `TEST_COMMAND <cmd...>` - Test command (supports variable substitution)
- `TEST_BEFORE_INSTALL` - Run tests before install
- `TEST_AFTER_INSTALL` - Run tests after install

#### Command Variable Substitution

All command arguments support `@VARIABLE@` substitution:
- `@PREREQUISITE_NAME@` - The prerequisite name
- `@PREREQUISITE_PREFIX@` - The prefix directory  
- `@PREREQUISITE_SOURCE_DIR@` - Source directory path
- `@PREREQUISITE_BINARY_DIR@` - Build directory path
- `@PREREQUISITE_INSTALL_DIR@` - Install directory path
- `@PREREQUISITE_STAMP_DIR@` - Stamp directory path
- `@PREREQUISITE_LOG_DIR@` - Log directory path

Examples:
```cmake
CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=@PREREQUISITE_INSTALL_DIR@
BUILD_COMMAND cmake --build @PREREQUISITE_BINARY_DIR@ --parallel
INSTALL_COMMAND make -C @PREREQUISITE_BINARY_DIR@ install
```

#### Logging Options
- `LOG_DOWNLOAD <bool>` - When true, redirect download step output to log files instead of console
- `LOG_UPDATE <bool>` - When true, redirect update step output to log files instead of console  
- `LOG_CONFIGURE <bool>` - When true, redirect configure step output to log files instead of console
- `LOG_BUILD <bool>` - When true, redirect build step output to log files instead of console
- `LOG_INSTALL <bool>` - When true, redirect install step output to log files instead of console
- `LOG_TEST <bool>` - When true, redirect test step output to log files instead of console
- `LOG_OUTPUT_ON_FAILURE <bool>` - When true, only show captured log output if the step fails

**Normal behavior**: Step output appears directly in CMake configure log or build output
**With LOG_* true**: Step output is captured to automatically named files like `<name>-build-out.log` in LOG_DIR, console shows only summary messages

Example: Without `LOG_BUILD`, you see thousands of compiler lines. With `LOG_BUILD true`, you see "Building prerequisite... (logged to file)" and can examine the log file if needed.

#### Control Options
- `BUILD_ALWAYS` - Always rebuild regardless of stamps
- `<STEP>_ALWAYS` - Always run specific step (e.g., `CONFIGURE_ALWAYS`)

### Prerequisite_Add_Step

Add a custom step to a prerequisite.

**Synopsis:**
```
Prerequisite_Add_Step(<name> <step> [options...])
```

**Options:**
- `COMMAND <cmd...>` - Command to execute
- `DEPENDEES <steps...>` - Steps this depends on
- `DEPENDERS <steps...>` - Steps that depend on this
- `WORKING_DIRECTORY <dir>` - Working directory for command
- `ALWAYS` - Always run this step

### Prerequisite_Get_Property

Retrieve properties from a prerequisite.

**Synopsis:**
```
Prerequisite_Get_Property(<name> <property> <output_variable>)
```

**Properties:**
All options from `Prerequisite_Add` can be retrieved as properties.

### Prerequisite_Force_Step

Force execution of a step and all subsequent steps.

**Synopsis:**
```
Prerequisite_Force_Step(<name> <step>)
```

This function is typically called by phony targets to force rebuilds.

### Prerequisite_Step_Current

Check if a step is up-to-date.

**Synopsis:**
```
Prerequisite_Step_Current(<name> <step> <output_variable>)
```

Sets output variable to TRUE if step is current, FALSE if it needs to run.


## Build-Time Targets

The Prerequisites system creates build-time targets for each prerequisite:

### Step Targets
For each prerequisite, the following targets are created:
- `<name>-download` - Ensures download and all subsequent steps are complete
- `<name>-configure` - Ensures configure and all subsequent steps are complete
- `<name>-build` - Ensures build and all subsequent steps are complete
- `<name>-install` - Ensures install and all subsequent steps are complete
- `<name>-test` - Ensures test step is complete (if defined)

### Force Targets
Additional "force" targets are automatically created:
- `<name>-force-download` - Forces re-download and all subsequent steps
- `<name>-force-configure` - Forces re-configure and all subsequent steps
- `<name>-force-build` - Forces rebuild and all subsequent steps
- etc.

### Target Implementation

Build-time targets are implemented using `add_custom_command()` chains:

1. Each step has a custom command that:
   - Depends on the previous step's stamp file
   - Runs the actual step command (build, install, etc.)
   - Creates its own stamp file on success

2. A custom target wraps each command:
   - `add_custom_target(${name}-${step} DEPENDS ${stamp_file})`
   - Provides a named target for `add_dependencies()`

3. Force targets bypass stamp checking:
   - Delete the stamp before running
   - Ensure step always executes

Example dependency chain:
```
configure stamp → build command → build stamp → install command → install stamp
```

This allows proper integration with CMake's dependency system while maintaining the ability to bootstrap at configure time.

## Execution Order and Dependencies

### Configure-Time Execution Order

**Critical**: At configure time, prerequisites execute in the order they appear in your CMakeLists.txt, NOT based on `DEPENDS`. The `DEPENDS` option only affects build-time target dependencies.

**Correct approach:**
```cmake
# List prerequisites in dependency order
Prerequisite_Add(compiler ...)        # Builds compiler first
Prerequisite_Add(libc DEPENDS compiler ...)  # Builds libc second (compiler already built)
project(MyProject C)
```

**Incorrect approach:**
```cmake
# This will fail - libc tries to build before compiler exists
Prerequisite_Add(libc DEPENDS compiler ...)  # Executes first, but compiler doesn't exist yet!
Prerequisite_Add(compiler ...)        # Executes second, too late
```

### Build-Time Dependencies

At build time, `DEPENDS` creates proper target dependencies:
- `libc-install` will depend on `compiler-install`
- Missing dependency targets will be built automatically
- Supports parallel builds and proper incremental rebuilds

## Error Handling

- Failed steps abort the configuration process
- Failed steps invalidate all subsequent step stamps
- Error output is captured in log files when logging is enabled
- Commands can check return codes and handle errors appropriately

## Usage Example

```cmake
# BEFORE project() - This is crucial!

# First, build the MOS compiler since CMake will need it when project() is called
Prerequisite_Add(llvm-mos
  GIT_REPOSITORY https://github.com/llvm-mos/llvm-mos.git
  GIT_TAG main
  CMAKE_ARGS 
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX=@PREREQUISITE_INSTALL_DIR@
  BUILD_COMMAND cmake --build @PREREQUISITE_BINARY_DIR@ --parallel
  LOG_BUILD
  LOG_OUTPUT_ON_FAILURE
)

# Now build picolibc using the compiler we just built
# Note: At this point llvm-mos is fully built and installed
set(ENV{PATH} "${CMAKE_CURRENT_BINARY_DIR}/prerequisites/install/bin:$ENV{PATH}")
Prerequisite_Add(picolibc
  DEPENDS llvm-mos  # This causes immediate check and recursive build if needed
  GIT_REPOSITORY https://github.com/picolibc/picolibc.git
  GIT_TAG main
  CONFIGURE_COMMAND meson setup @PREREQUISITE_BINARY_DIR@ @PREREQUISITE_SOURCE_DIR@
    --cross-file mos-cross.txt
    --prefix=@PREREQUISITE_INSTALL_DIR@
  BUILD_COMMAND ninja -C @PREREQUISITE_BINARY_DIR@
  INSTALL_COMMAND ninja -C @PREREQUISITE_BINARY_DIR@ install
)

# NOW we can declare our project, and CMake will find the compiler we built
project(MyMOSProject C ASM)

# The compiler and libraries are already installed and ready to use

# But we can ALSO use prerequisites as build-time dependencies:
add_executable(my_app main.c)
# This ensures picolibc is built/installed before my_app:
add_dependencies(my_app picolibc-install)

# If someone deletes the picolibc install, the build-time target will rebuild it
# If stamps are intact, the target does nothing (fast incremental builds)
```