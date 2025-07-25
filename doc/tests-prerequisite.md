# Prerequisites Test Suite Plan

## Overview

This document outlines the comprehensive test strategy for the CMake prerequisites system. The test suite validates the dual execution model, dependency tracking mechanisms, and integration scenarios that make prerequisites unique from ExternalProject.

## Test Architecture

### Directory Structure

**Current Implementation (July 2025):**
```
tests/prerequisite/
├── CMakeLists.txt         # Test suite runner with add_prerequisite_test()
├── simple/                # Basic functionality tests
│   ├── immediate/         # Configure-time execution test
│   └── deferred/          # Build-time execution test
└── stamp/                 # Stamp file behavior validation
    ├── behavior/          # Basic stamp creation test
    ├── incremental/       # Counter-based re-execution detection
    ├── reconfig/          # Reconfiguration behavior validation  
    └── missing/           # Missing stamp rebuild testing
```

**Planned Future Structure:**
```
tests/prerequisite/
├── simple/                # IMPLEMENTED - Basic functionality
├── stamp/                 # IMPLEMENTED - Stamp file behavior  
├── execution/             # Dual execution model edge cases
├── tracking/              # File-based dependency tracking
├── dependencies/          # Inter-prerequisite relationships
├── steps/                 # Step execution and sequencing
├── integration/           # Real-world scenarios with mocks
├── error/                 # Error handling and recovery
├── fixtures/              # Reusable test infrastructure
├── data/                  # Test data and expected results
└── utils/                 # Test utilities and helpers
```

### Test Framework

### Framework Design Rationale

The prerequisites system has unique testing challenges that drive our framework choices. The core issue is that prerequisites must work both before and after the `project()` command, creating timing dependencies that require true process isolation to test properly.

**Why CTest:** We use CMake's built-in `add_test()` and `ctest` because each test essentially needs to be "run cmake and verify the result" - which is exactly what CTest handles well. The parallel execution, timeout handling, and integration with standard build tools (`make test`) are all valuable. Most importantly, CTest naturally runs each test as a separate process, which we need anyway.

**Why process isolation is critical:** The dual execution model means prerequisites behave completely differently when called before vs after `project()`. Before `project()`, they execute immediately and block configuration. After `project()`, they only create build targets. Testing this requires separate CMake processes because once `project()` is called in a CMake run, you can't "uncall" it. Each test needs a fresh CMake environment to properly test the timing-sensitive behavior.

**Why CMake script mocks:** External tools (git, cmake, make) need to be mocked because we're testing prerequisites system behavior, not the external tools themselves. CMake scripts work well as mocks because they can create the files and directories that prerequisites expect while being controllable from our test framework. They're also cross-platform without requiring shell script complexity.

**Why validate both artifacts and outputs:** Prerequisites create two types of evidence - files/directories (stamps, downloaded source, built binaries) and process behavior (exit codes, error messages, execution order). The dual execution model means we need to verify both that the right things got built AND that they got built at the right time. Output comparison against known good files helps verify that complex multi-prerequisite scenarios execute in the correct order.

**Implementation approach:** Start with basic tests against stubs to validate the testing framework itself, then implement minimal Prerequisite_Add() functionality to support the tests. This prevents building a complex test suite against non-existent functionality while ensuring the framework can actually test what we're building.

## Critical Test Categories

### 1. Dual Execution Model (High Priority)

**Configure-time execution:**
- Prerequisites before `project()` execute immediately during configure
- Configuration blocks until prerequisite completion
- Multiple prerequisites execute in CMakeLists.txt order (not DEPENDS order)
- Environment changes persist between prerequisites
- Stamp files created during configure-time execution

**Build-time execution:**
- Prerequisites after `project()` only create build targets
- Build targets respect existing stamps from configure-time execution
- Same commands produce identical results in both modes
- Force targets bypass dependency checking

**Mixed scenarios:**
- Some prerequisites at configure-time, others at build-time
- Build targets integrate correctly with configure-time results
- Incremental rebuilds work after initial bootstrap

### 2. Dependency Tracking Systems (High Priority)

**Stamp-based tracking:**
- Successful steps create stamp files with correct timestamps
- Existing stamps prevent step re-execution
- Missing stamps trigger step and all subsequent steps
- Failed steps clean up their own and subsequent stamps
- Manual stamp deletion forces rebuilds

**File-based tracking:**
- Steps with file dependencies completely replace stamp behavior
- File changes trigger appropriate step re-execution  
- GLOB and GLOB_RECURSE patterns work correctly
- Variable substitution in glob patterns (@PREREQUISITE_SOURCE_DIR@/*.c)
- File tracking works with CMake's normal dependency resolution

**Mixed tracking:**
- Different steps in same prerequisite use different tracking methods
- No interference between stamp-based and file-based steps
- Dependency chains work across mixed tracking methods

### 3. Variable Substitution (High Priority)

**All @PREREQUISITE_*@ variables:**
- @PREREQUISITE_NAME@ - prerequisite name
- @PREREQUISITE_PREFIX@ - prefix directory
- @PREREQUISITE_SOURCE_DIR@ - source directory path
- @PREREQUISITE_BINARY_DIR@ - build directory path  
- @PREREQUISITE_INSTALL_DIR@ - install directory path
- @PREREQUISITE_STAMP_DIR@ - stamp directory path
- @PREREQUISITE_LOG_DIR@ - log directory path

**Substitution contexts:**
- All *_COMMAND options (DOWNLOAD_COMMAND, BUILD_COMMAND, etc.)
- All *_DEPENDS glob patterns
- Directory path options
- CMAKE_ARGS and similar argument lists

**Edge cases:**
- Paths with spaces and special characters
- Variables within variables
- Platform-specific path separators
- Escaping and quoting behavior

### 4. Inter-prerequisite Dependencies (High Priority)

**Configure-time behavior:**
- DEPENDS option does NOT enforce configure-time ordering
- Prerequisites execute in CMakeLists.txt order regardless of DEPENDS
- Environment and PATH changes flow between prerequisites
- Later prerequisites can use artifacts from earlier ones

**Build-time behavior:**
- DEPENDS creates proper CMake target dependencies
- A-install depends on B-install when A DEPENDS B
- Missing dependency targets built automatically
- Circular dependency detection and error reporting

**Complex scenarios:**
- Multi-level chains: A depends on B depends on C
- Environment passing: compiler built first, used by library second
- Cross-prerequisite file dependencies

### 5. Step Execution and Sequencing (Medium Priority)

**Standard step sequence:**
- download → update → configure → build → install → test
- Triggering any step runs all subsequent steps
- Test step can run independently without triggering others
- Empty commands result in no-op steps

**Custom steps:**
- DEPENDEES and DEPENDERS relationships work correctly
- Custom steps integrate into standard sequence
- WORKING_DIRECTORY option works
- ALWAYS option forces execution

**Force targets:**
- Force targets created for all steps (name-force-step)
- Force targets delete appropriate stamps before execution
- Force targets run target step and all subsequent steps

### 6. Error Handling and Recovery (Medium Priority)

**Failure scenarios:**
- Failed configure-time execution aborts configuration with clear error
- Failed build-time execution reports errors appropriately  
- Partial failures don't leave inconsistent stamp states
- Network failures during download handled gracefully

**Logging:**
- LOG_* options capture output to correct files
- LOG_OUTPUT_ON_FAILURE shows errors when needed
- Log files created in correct directories (LOG_DIR or STAMP_DIR)
- Console output vs log file behavior matches documentation

**Recovery:**
- Force targets enable recovery after fixing issues
- Stamp cleanup after failures prevents inconsistent states
- Manual stamp deletion works for troubleshooting

## Mock Strategy

### External Tool Mocking
- Mock `cmake`, `git`, `make`, `wget`, `curl` executables
- Mocks validate correct arguments passed to external tools
- Mocks can simulate failures for error testing
- Mocks produce expected outputs (files, directories) for testing

### Mock Project Types
- **Simple:** Just creates output files to verify execution
- **Complex:** Multiple outputs, file dependencies, realistic structure
- **Failing:** Fails at specific steps for error testing
- **Conditional:** Behavior varies based on arguments/environment

## Platform Testing Strategy

### Cross-platform scenarios:
- Path separator handling (/ vs \\)
- Executable extensions (.exe on Windows)
- Case sensitivity differences
- Permission and access scenarios
- Environment variable handling

### Generator compatibility:
- Unix Makefiles
- Ninja  
- Visual Studio (Windows)
- Xcode (macOS)

## Test Implementation Guidelines

### Test Isolation
- Each test runs in isolated directory
- Cleanup utilities ensure no test pollution
- Mock tools don't interfere with real system tools
- Environment variables restored after each test

### Assertion Strategy
- Custom assertion functions for common checks
- File existence and content validation
- Timestamp comparison utilities  
- Directory structure validation
- Log file content verification

### Test Data Management
- Small test archives and files in `data/`
- Generated content where possible to minimize repository size
- Template-based configuration files
- Expected output files for comparison

## Implementation Priority

1. **Phase 1:** COMPLETE - Unit tests and basic execution model
2. **Phase 2:** PARTIAL - Dependency tracking (stamps complete, files pending)
3. **Phase 3:** IN PROGRESS - Variable substitution and inter-prerequisite dependencies
4. **Phase 4:** PLANNED - Error handling and platform compatibility
5. **Phase 5:** PLANNED - Integration scenarios and edge cases

## Success Criteria

The test suite is complete when:
- All documented prerequisites.md functionality is validated
- Both configure-time and build-time execution paths tested
- All variable substitution scenarios covered
- Error conditions handled gracefully
- Cross-platform compatibility verified
- Test suite runs in reasonable time (<5 minutes total)
- Tests are maintainable and well-documented

## Current Implementation Status (July 2025)

### IMPLEMENTED - Basic Test Infrastructure
- **CTest Integration**: Uses `add_prerequisite_test()` function for process isolation
- **Cross-generator Support**: Tests pass identically with make and ninja
- **Test Organization**: Organized into `simple/` and `stamp/` directories

### IMPLEMENTED - Simple Functionality Tests (`simple/`)
- **`immediate`**: Validates configure-time execution before `project()`
- **`deferred`**: Validates build-time target creation after `project()`
- **Property Retrieval**: Tests `Prerequisite_Get_Property()` functionality
- **Debug Output**: Validates `_Prerequisite_Debug_Dump()` function

### IMPLEMENTED - Stamp File Behavior Tests (`stamp/`)

**Critical Tests That WILL FAIL if Stamps Break:**

- **`incremental`**: Uses execution counters that fail with `"STAMP FAILURE: X step executed N times, expected 1"` if any step runs more than once
- **`reconfig`**: Tracks executions across reconfigurations, fails with `"STAMP FAILURE: Prerequisite executed N times across reconfigurations"` if steps re-run when stamps exist  
- **`missing`**: Removes stamps and verifies rebuild, fails with `"STAMP FAILURE: Missing stamp did not trigger rebuild"` if outputs aren't recreated
- **`behavior`**: Basic validation that stamps are created and respected

### CURRENT LIMITATIONS
- **File-based dependency tracking**: Not yet implemented (only stamp-based works)
- **Variable substitution**: Works for immediate execution, not for build-time commands
- **Logging support**: `LOG_*` options parsed but ignored
- **Error handling**: Limited validation of failure scenarios
- **Inter-prerequisite dependencies**: Basic implementation, needs comprehensive testing

### NEXT PRIORITY AREAS
1. **File dependency tracking tests** (`tracking/` directory)
2. **Variable substitution validation** in build-time contexts
3. **Inter-prerequisite dependency tests** (`dependencies/` directory)
4. **Error handling and recovery tests** (`error/` directory)
5. **Integration scenarios with mocks** (`integration/` directory)

### Test Execution Summary
```bash
# Run all tests
cd build && cmake ../tests/prerequisite && ctest

# Current results: 11/11 tests passing
# Total execution time: ~0.75 seconds
# Generators tested: Unix Makefiles, Ninja
```

See `doc/todo.md` for detailed development status and implementation priorities.

## Notes for Implementation

- Start with simplest unit tests to establish framework
- Build up complexity gradually through phases
- Focus on the unique aspects of prerequisites vs ExternalProject
- Mock external tools rather than requiring real installations
- Prioritize the dual execution model as core differentiator
- Ensure tests are deterministic and don't depend on timing
- Document expected behavior clearly in test descriptions