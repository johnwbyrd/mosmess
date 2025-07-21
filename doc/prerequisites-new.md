# CMake prerequisites system

## Introduction

The prerequisites system lets you build external dependencies during CMake's configuration phase, before the `project()` command runs. This is crucial when you need to build the very tools that CMake is about to look for.

For example: CMake's `project()` command needs a working compiler and maybe some libraries. It runs detection tests, checks features, and generally assumes your toolchain exists. But what if you're building that compiler from source? What if you need a custom library that doesn't exist yet? You're stuck -- CMake needs these tools to configure your project, but you need CMake to build the tools.

The prerequisites system breaks this deadlock. It can build your dependencies immediately during configuration (so they're ready when `project()` runs), and it also creates normal CMake targets for incremental rebuilds later.

ExternalProject can't help here -- it only runs at build time, after configuration is done. FetchContent is great for pulling in CMake-based libraries, but it can't bootstrap a compiler. Prerequisites handles both the bootstrap problem and ongoing development in one system.

## Core concepts

### Dual execution model

The prerequisites system can run at both configure time _and_ at build time. This isn't an accident -- it's what makes the whole thing useful.

When you call `Prerequisite_Add()` before `project()`, the system checks if your prerequisite needs building. If it does, it runs the build steps right then and there using `execute_process()`. Your CMake configuration pauses, the compiler gets built, and then configuration continues. This is how you bootstrap -- by the time CMake hits `project()` and starts looking for a compiler, it's already there.

But the system _also_ creates regular CMake targets for every prerequisite. These targets check the same stamp files and run the same commands, but they execute during the build phase like any other target. So if you modify your prerequisite's source code and rebuild your main project, the prerequisite rebuilds automatically.

This dual approach means you write your prerequisite once and it works for both scenarios. Initial bootstrap? It runs immediately. Daily development? It's just another dependency. Same code, same commands, two execution paths.

### Dependency tracking methods

The prerequisites system needs to know when to rebuild things. It offers two ways to track this: simple stamp files or detailed file dependencies.

By default, the system uses stamp files -- just empty files that mark when a step completed successfully. If the stamp exists, the step is done. If it's missing, the step runs. This is fast and simple, but it's all-or-nothing. The downside is changes to your prerequisite's source files are not automatically detected, and your prerequisite is not automatically rebuilt.

The alternative is file dependency tracking. You tell each step which files it actually depends on, by using CMake's file glob patterns. Before running a step, the system checks if any of those files are newer than the stamp. Changed a source file? Only the build step reruns. Changed CMakeLists.txt? Now configure needs to run too. It's smarter and saves time, especially with large projects.

The catch is that file tracking requires more setup and more build-time overhead. You need to know which files matter for each step, write the glob patterns correctly, and accept that checking hundreds of file timestamps in your prerequisite, takes some incremental amount of time.

Most projects mix both approaches. Use stamps for stable steps (download, configure) and add file tracking where it helps most (build, install). A typical setup might track source files for the build step but use simple stamps for everything else. This gets you fast rebuilds during development without overcomplicating the whole system.

### Step-based architecture

Prerequisites are built through a series of ordered steps, mimicking how you'd build software manually. Each step has a specific job and they run in a fixed sequence.

The standard steps are: download, update, configure, build, install, and test. Not every prerequisite uses all steps -- you might skip update if you're building from a tarball, or skip test if there's nothing to test. But when steps do run, they always run in this order.

Here's the key rule: when you trigger any step, all subsequent steps run too. Ask for build? You get build, install, and test. Ask for download? You get the whole chain. This seems wasteful at first, but it ensures consistency. If you've changed the build, the old installation is stale. If you've downloaded new source, the old build is useless. The only exception is the test step -- you can run tests repeatedly without triggering anything else.

Each step is just a command or set of commands. Download might run `git clone`. Configure might run `cmake` or `./configure`. Build runs `make` or `ninja`. You provide these commands when defining your prerequisite, and the system runs them at the appropriate time with the appropriate checks.

This design keeps prerequisites predictable. You always know what will happen when you trigger a step, and you can't accidentally end up with a partially updated prerequisite where the headers don't match the libraries.

Remember that each step can use either stamp tracking or file dependency tracking independently. You might use simple stamps for download and configure, but add file dependency tracking just for the build step. This per-step choice lets you optimize exactly where it matters.

## System design

### Execution flow

When you call `Prerequisite_Add()`, several things happen in sequence, and the order matters.

First, the function stores all your settings -- the commands, directories, dependencies, everything. This information needs to be available later, whether for immediate execution or for creating build targets.

Next, if you're running before `project()`, the system checks whether this prerequisite needs to build. For each step, it checks dependencies - either looking for stamp files or checking if tracked files have changed, depending on how you configured that step. If any step needs to run, it executes immediately using `execute_process()`. The system runs the command, checks if it succeeded, and updates tracking information (stamps or file lists). This all happens during CMake configuration, blocking until done.

Then, regardless of whether anything built, the system creates CMake targets for every step. It generates `add_custom_command()` rules that respect the same dependency logic - stamps for some steps, file dependencies for others. Some steps might not produce stamps at all if they're using file tracking exclusively. The dependency chain ensures steps run in order, using whatever tracking method each step requires. The system also creates convenient targets like `myprereq-build` that you can invoke directly or use with `add_dependencies()`, which in turn use ordinary CMake dependencies for running that step as well as previous ones, as needed.

Whether a step runs immediately during configuration or later during build, it uses the same commands and the same dependency logic. The only difference is timing -- immediate when bootstrapping, deferred when developing.

### Directory layout

Prerequisites need a place to download source, build, and install files. The system uses a predictable layout that keeps things organized and avoids conflicts.

By default, everything goes under a PREFIX directory, following ExternalProject's layout exactly. If you don't specify a PREFIX, it defaults to `<name>-prefix`. For a prerequisite named `myprereq`, you'd get:
- `PREFIX/src/myprereq` - Source code lives here
- `PREFIX/src/myprereq-build` - Build happens here (out-of-source)
- `PREFIX/src/myprereq-stamp` - Stamp files track completion
- `PREFIX/src` - Downloaded files go here before extraction
- `PREFIX/tmp` - Temporary files during operations
- `PREFIX` - Installation goes directly in prefix

This matches ExternalProject's directory structure exactly, so it'll feel familiar if you've used that. The separation between source and build directories enables clean out-of-source builds, which most modern projects expect.

You can override any of these locations. Maybe you have source code already checked out somewhere, or you want stamps in a specific spot for caching. Just set SOURCE_DIR, BINARY_DIR, STAMP_DIR, DOWNLOAD_DIR, or INSTALL_DIR when calling `Prerequisite_Add()`. The system respects your choices and adjusts all the internal paths accordingly.

The PREFIX approach also makes it easy to share installations. Multiple prerequisites can install into the same PREFIX, creating a unified location for all your bootstrapped tools. This is especially handy when building a complete toolchain where later prerequisites need to find earlier ones.

### Stamp file mechanics

Stamp files are the default way the system tracks which steps have completed successfully. Like ExternalProject, the prerequisites system creates simple timestamp files to remember what's been done.

When a step finishes successfully, the system creates an empty file in the stamp directory. For a prerequisite named `myprereq`, you'd see files like `myprereq-download`, `myprereq-configure`, `myprereq-build`, etc. These aren't complex databases or logs -- just empty marker files whose timestamps matter.

Before running any step, the system checks for its stamp file. If it exists, the step is considered done and gets skipped. If it's missing, the step runs. This simple logic is fast and reliable, but it's all-or-nothing -- the system can't tell what changed, only whether the step completed.

When a step fails, the system cleans up by removing stamps for that step and all subsequent steps. This prevents inconsistent states where you might have a build stamp but no install stamp because the build actually failed. It's better to rebuild too much than to have a half-working prerequisite.

File dependency tracking changes this behavior. When you add file dependencies to a step, the system compares file timestamps instead of just checking for stamp existence. A step runs if any of its tracked files are newer than the stamp, even if the stamp exists. This gives you precise rebuilds based on what actually changed, not just whether something completed before.

You can manually control stamps by deleting them to force rebuilds. Want to reconfigure? Delete `myprereq-configure` and all later stamps. This manual control is often the simplest way to fix build problems or test changes.

### Build target generation

The prerequisites system creates standard CMake targets for every prerequisite, giving you normal CMake integration alongside the bootstrap capability.

For each step in your prerequisite, the system generates an `add_custom_command()` rule. For steps using stamp tracking, the command's output is the step's stamp file, and it depends on the previous step's output. For steps using file dependency tracking, the command depends on the tracked files and may or may not produce a stamp -- the dependency logic handles file timestamps directly. When make or ninja sees that outputs are missing or dependencies are newer, it runs the associated command.

The system also creates convenient targets for each step using `add_custom_target()`. A prerequisite named `myprereq` gets targets like `myprereq-download`, `myprereq-build`, `myprereq-install`, etc. These targets depend on whatever output their step produces -- stamp files for stamp-tracked steps, or the actual command execution for file-tracked steps.

Additionally, the system creates "force" targets that bypass dependency checking entirely. `myprereq-force-build` forces the build step to run regardless of stamps or file timestamps, then continues with subsequent steps. This gives you an easy way to force rebuilds when debugging or testing changes.

The beauty of this approach is that these are just normal CMake targets. You can use them with `add_dependencies()` to make your main project depend on prerequisite steps. You can invoke them manually from the command line. They participate in parallel builds and respect CMake's dependency tracking.

Most importantly, these targets run the exact same commands as immediate execution. Whether a step runs during configuration via `execute_process()` or during build via these targets, the commands, arguments, and environment are identical. This consistency means prerequisites behave the same way regardless of when they execute.

## Usage patterns

### Basic bootstrapping

[Building a compiler before project()]

### Iterative development

[Using prerequisites during active development]

### Mixed dependency tracking

[Combining stamps and file dependencies effectively]

## Function reference

### Prerequisite_Add

Main function to define a prerequisite.

**Synopsis:**
```
Prerequisite_Add(<name> [options...])
```

**Options:**

#### Dependency Options
- `DEPENDS <prereqs...>` - Names of other prerequisites that must be built first.
  - **Configure time**: Does NOT enforce dependencies -- prerequisites execute in the order they appear in your CMakeLists.txt
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