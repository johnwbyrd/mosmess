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

The Prerequisites system operates in a fundamentally different way than traditional CMake dependency management. It provides both immediate execution during configuration and deferred execution through build targets, solving the bootstrapping problem while maintaining proper dependency tracking.

When CMake processes a `Prerequisite_Add()` call before the `project()` statement, the system can execute build steps immediately using `execute_process()`. This immediate execution is essential for bootstrapping scenarios where you need to build the compiler that CMake will detect when it reaches the `project()` command. The configuration process blocks while these commands run, which is why initial configuration can be slow when building large prerequisites like LLVM. However, this synchronous execution ensures that by the time `project()` is called, all necessary tools and libraries exist and are ready for detection.

Simultaneously, the system creates standard CMake build targets for every prerequisite, regardless of when `Prerequisite_Add()` was called. These targets form a proper dependency chain using `add_custom_command()` with stamp files as outputs. For example, the `llvm-mos-build` target depends on the configure stamp file and produces the build stamp file. This integration with CMake's normal dependency system means that your main project can depend on prerequisite targets just like any other dependency, enabling incremental rebuilds and proper parallel execution during development.

The dual nature of this system provides maximum flexibility. During initial setup, prerequisites build immediately to bootstrap the environment. During subsequent development, the same prerequisites participate in the normal build process, rebuilding only when their dependencies change. This design elegantly solves both the chicken-and-egg problem of building compilers and the ongoing need for incremental rebuilds during development.

## Dependency Tracking Methods

The Prerequisites system offers two ways of tracking whether a prerequisite needs some or all of its build steps reiterated.

By default, the system uses stamp-based tracking, where each successfully completed step creates a simple timestamp file. When a prerequisite is requested, the system checks whether these stamp files exist. If they do, the step is considered complete and is skipped. If not, the step runs along with all subsequent steps. This approach is fast and simple - checking for file existence is nearly instantaneous, and the logic is straightforward. However, it's also quite coarse-grained. Any change to the prerequisite requires manually deleting stamp files to force a rebuild, and there's no way to detect which specific files changed or whether a rebuild is actually necessary.

The alternative is file dependency tracking, where you explicitly tell each step which files it depends on using glob patterns. Before running a step, the system checks whether any of these files have been modified more recently than the step's stamp file. This enables much more intelligent rebuild behavior. For instance, if you modify a source file in LLVM, only the build, install, and test steps need to re-run - the expensive configure step can be skipped because CMakeLists.txt hasn't changed. This granular tracking is especially valuable during active development of prerequisites, where you might be iterating on patches or modifications.

The cost of this precision is complexity and performance. File dependency tracking requires scanning potentially thousands of files to check their timestamps, which can add overhead to every build. More importantly, it requires understanding the internal structure of each prerequisite well enough to write accurate glob patterns. If your patterns are too broad, you'll rebuild unnecessarily. If they're too narrow, you'll miss changes and get stale builds. The patterns may also need maintenance as the prerequisite project evolves.

In practice, the best approach often combines both methods. Use stamp-based tracking for stable steps that rarely change, like download and configure, while adding file dependency tracking to steps that you're actively modifying, like build and install. This gives you fast incremental builds where they matter most without the overhead of tracking every possible file. The system is designed to make this mixed approach natural - simply add `*_DEPENDS` options only to the steps where you need fine-grained tracking.

### How It Works

The `Prerequisite_Add()` function orchestrates both execution modes seamlessly. When called before `project()`, it first checks whether the prerequisite's steps need to run by examining stamp files. If stamps are missing or forced execution is requested, it immediately executes the necessary steps using `execute_process()`, blocking until completion. This ensures that compilers and libraries exist before CMake's project initialization needs them.

Regardless of when it's called or whether immediate execution occurred, `Prerequisite_Add()` always creates a complete set of build-time targets. These targets form a dependency chain where each step depends on the previous step's stamp file and produces its own stamp as output. The build targets use the exact same commands as immediate execution, maintaining consistency. This dual approach means that subsequent project targets can depend on prerequisites naturally - if the prerequisite already ran at configure time, the build targets see valid stamps and do nothing. If not, or if files have changed, the build targets execute the necessary steps.

### Implementation Details

The key to the Prerequisites system's flexibility lies in how both execution modes share the same underlying step logic. Whether a step runs immediately during configuration or later during the build, the actual commands executed are identical. This consistency ensures that prerequisites behave the same way regardless of when they execute.

During immediate execution at configuration time, the system uses CMake's `execute_process()` to run commands synchronously. After each command completes, CMake code checks the return status and creates stamp files to record successful completion. This blocking behavior means configuration waits for each prerequisite to finish, which is why bootstrapping can take significant time but ensures everything is ready before proceeding.

For build-time execution, the system creates chains of `add_custom_command()` rules where stamp files serve as outputs. This leverages CMake's standard dependency tracking - when make or ninja sees that a stamp file is missing or out of date, it runs the associated command. The commands execute directly in the build tool without reinvoking CMake, providing efficient incremental builds. Since these targets are created during configuration but execute during build, there's no configuration-time blocking for prerequisites that already have valid stamps.

### Performance Implications

The performance characteristics of the Prerequisites system vary dramatically between first run and incremental use. Initial configuration when prerequisites need building can take hours for large projects like LLVM, as the entire compiler must be built before CMake can proceed. However, subsequent configurations are fast because the stamp files prevent re-execution of completed steps. During normal development, the system provides standard incremental build performance through CMake's dependency tracking, with changes to prerequisites triggering only the minimal necessary rebuilds. This design accepts slow initial setup as the price for enabling true bootstrapping from source.

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

The Prerequisites system enforces a strict execution order to maintain consistency. When any step is requested, whether through immediate execution or build targets, the system runs that step and all subsequent steps in the chain. This design reflects the reality that later steps depend on earlier ones - you cannot install what hasn't been built, and changes to the build typically invalidate the installation.

For example, requesting the "build" step doesn't just compile the software. It triggers build, install, and test in sequence. This ensures that if you've made changes significant enough to require rebuilding, those changes are properly propagated through installation and testing. Similarly, requesting "download" runs the entire chain from download through test, because new source code requires reconfiguration, rebuilding, and reinstallation. Only the "test" step stands alone, as testing can be repeated without affecting other steps. This execution model prevents subtle bugs that arise from partially updated prerequisites where, for instance, headers in the install directory don't match the rebuilt libraries.

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

#### File Dependency Options

These options enable intelligent rebuild behavior by tracking changes to specific files within a prerequisite's source tree, rather than relying solely on timestamp-based stamp files.

- `DOWNLOAD_DEPENDS <args...>` - File dependency arguments for download step
- `UPDATE_DEPENDS <args...>` - File dependency arguments for update step
- `CONFIGURE_DEPENDS <args...>` - File dependency arguments for configure step
- `BUILD_DEPENDS <args...>` - File dependency arguments for build step
- `INSTALL_DEPENDS <args...>` - File dependency arguments for install step
- `TEST_DEPENDS <args...>` - File dependency arguments for test step

**Purpose:**
File dependency tracking allows prerequisites to rebuild only when their internal dependencies have actually changed. For example, if you modify source files in a prerequisite, only the build/install/test steps need to re-run, not the download/configure steps. This provides more granular and efficient rebuild behavior than simple timestamp checking.

**File Dependency Behavior:**
- All arguments are passed directly to CMake's `file()` command
- First argument should typically be `GLOB` or `GLOB_RECURSE`
- Second argument should typically be `@PREREQUISITE_FILE_RESULT@` (used internally by system)
- Remaining arguments are glob patterns with variable substitution applied
- If file dependencies exist, they override timestamp-based stamp checking
- Step runs if any dependency file is newer than the stamp, or if stamp doesn't exist

Examples:
```cmake
Prerequisite_Add(my_project
  GIT_REPOSITORY https://github.com/example/project.git
  GIT_TAG main
  
  # Configure step depends on CMake files
  CONFIGURE_DEPENDS GLOB @PREREQUISITE_FILE_RESULT@ CMakeLists.txt cmake/*.cmake
  
  # Build step depends on source files recursively  
  BUILD_DEPENDS GLOB_RECURSE @PREREQUISITE_FILE_RESULT@ 
    @PREREQUISITE_SOURCE_DIR@/*.cpp 
    @PREREQUISITE_SOURCE_DIR@/*.h
    
  # Install step depends on build outputs
  INSTALL_DEPENDS GLOB @PREREQUISITE_FILE_RESULT@ @PREREQUISITE_BINARY_DIR@/bin/*
)
```

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