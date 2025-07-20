# mosmes Implementation TODO

## Vector System Implementation Details

The vector system requires careful design to balance simplicity with flexibility. While the conceptual model of vector multiplication is straightforward, the implementation details involve several nuanced decisions about how vectors are defined, composed, and applied to targets.

### Vector Definition Mechanisms

The current design assumes vectors will be implemented as CMake functions that accept target names and apply appropriate properties. However, the specific interface for defining vectors needs elaboration. Should vectors be defined through a registration system similar to platforms, or should they be simple function definitions that follow naming conventions?

A registration approach would allow for better introspection and validation. For example, a `mos_register_vector(debug)` function could validate that the corresponding `mos_apply_debug_vector(target)` function exists and has the correct signature. This would enable better error reporting when users specify non-existent vectors.

Alternatively, a convention-based approach would require less infrastructure. Users could simply define functions following the pattern `mos_apply_<vector>_vector(target)` and specify vector names in their project configurations. The build system would attempt to call the corresponding functions and fail gracefully if they don't exist.

The registration approach provides better user experience through validation and introspection, but the convention-based approach requires less implementation complexity. The choice impacts how users discover available vectors and how errors are reported.

### Vector Composition and Conflicts

The Cartesian product approach to vector multiplication raises questions about how conflicting settings are resolved when multiple vectors affect the same properties. For instance, if both "debug" and "optimize" vectors attempt to set optimization flags, which takes precedence?

One approach is to define vector ordering semantically. Vectors specified later in the list could override properties set by earlier vectors. This provides predictable behavior but requires users to understand the ordering implications of their vector specifications.

Another approach is to detect conflicts and report errors, forcing users to explicitly resolve ambiguities. This prevents unexpected behavior but may be overly restrictive for legitimate use cases where property override is desired.

A hybrid approach might categorize properties by conflict behavior. Some properties (like preprocessor definitions) can be safely accumulated, while others (like optimization levels) represent mutually exclusive choices that require explicit resolution.

### Vector Parameterization

Some vectors may benefit from parameterization. A "optimize" vector might accept different optimization levels, or a "sanitize" vector might accept different sanitizer types. The current design doesn't address how such parameterization would be expressed in user configurations or implemented in vector functions.

Simple parameterization could use function arguments passed through the vector application mechanism. More complex parameterization might require vectors to be objects rather than simple functions, allowing for state storage and configuration validation.

The parameterization mechanism must balance expressiveness with simplicity. Users should be able to specify common variations easily while still having access to full customization when needed.

## Dependency Integration Implementation Analysis

The choice between FetchContent, ExternalProject, and alternative approaches involves significant trade-offs that affect user experience, build performance, and system complexity. Each approach has implications for dependency version management, incremental builds, and development workflow integration.

### ExternalProject Analysis

ExternalProject provides the most control over external dependency builds but at the cost of increased complexity and longer initial build times. ExternalProject treats each dependency as a completely separate build that runs during the main build process, which provides strong isolation but limits integration opportunities.

The primary advantage of ExternalProject is build system independence. Each external project can use its native build system (CMake for llvm-mos, Meson for picolibc) without requiring the main build to understand those systems' internals. This approach is robust against changes in external project build configurations and doesn't require intimate knowledge of external build processes.

However, ExternalProject's isolation comes with costs. Dependency builds cannot be easily parallelized with main project builds, leading to longer total build times. Additionally, ExternalProject doesn't integrate well with IDE development workflows, as external projects are not visible to CMake-based tooling.

ExternalProject also complicates the super-ninja integration approach. Since external projects are built through separate processes, their ninja files are not available for inclusion in the master ninja graph. This limitation effectively prevents the super-ninja mode when using ExternalProject dependency management.

### FetchContent Analysis

FetchContent provides tighter integration by incorporating external projects directly into the main build system. This approach enables better parallelization and IDE integration but requires more assumptions about external project build systems and configurations.

The primary advantage of FetchContent is build system unification. All components are built through a single CMake invocation, enabling parallel builds across project boundaries and full visibility for IDE tooling. FetchContent also integrates naturally with the super-ninja approach, as all projects contribute to the same ninja graph.

However, FetchContent's integration comes with significant limitations. It only works well when external projects use CMake or can be easily adapted to CMake. Projects using other build systems (like picolibc with Meson) require either complex wrapper logic or complete build system replacement, both of which are maintenance burdens.

FetchContent also provides less isolation than ExternalProject. Changes in external project build configurations can affect the main build, and debugging build issues becomes more complex when multiple projects are intermingled in a single build system invocation.

### Git Submodule Integration

An alternative approach involves using git submodules to incorporate external projects as source dependencies while maintaining separate build processes. This approach provides source-level integration for development workflows while preserving build system independence.

Git submodules ensure that all required source code is available locally and versioned consistently. Developers can make changes across project boundaries and commit them atomically. The super-ninja approach works naturally with submodules since all projects are present and can contribute their ninja files to the master graph.

However, submodules add complexity to repository management and can be confusing for developers unfamiliar with git submodule workflows. Additionally, this approach requires all dependencies to be built from source, which may not be appropriate for all deployment scenarios.

### Hybrid FetchContent/ExternalProject Approach

A promising approach would combine FetchContent and ExternalProject to leverage the advantages of both systems. FetchContent could handle initial dependency acquisition and source management, while ExternalProject could handle the actual building with each dependency's native build system.

The workflow would involve FetchContent downloading and making dependencies available as source, then ExternalProject configuring and building each dependency using its preferred build system. This approach provides source-level integration for development workflows while maintaining build system independence.

```cmake
# Use FetchContent to acquire sources
FetchContent_Declare(llvm-mos
  GIT_REPOSITORY https://github.com/llvm-mos/llvm-mos
  GIT_TAG main
)
FetchContent_Populate(llvm-mos)

# Use ExternalProject to build with native build system
ExternalProject_Add(llvm-mos-build
  SOURCE_DIR ${llvm-mos_SOURCE_DIR}
  CMAKE_ARGS -DCMAKE_BUILD_TYPE=Release
  BUILD_ALWAYS OFF  # Only rebuild if sources change
)
```

This hybrid approach enables the super-ninja integration since all sources are available locally, while still respecting each project's build system preferences. The FetchContent step provides consistent source management and git integration, while the ExternalProject step provides proper dependency ordering and incremental build support.

The combination also enables user choice in dependency management. Users could pre-populate the FetchContent cache with their preferred dependency versions, use git submodules to override specific dependencies, or allow automatic fetching for a fully automated build experience.

However, this approach requires careful coordination between the FetchContent and ExternalProject steps. Source directory management becomes more complex, and the build system must handle cases where sources are available but build artifacts are not, or vice versa.

### Hybrid Approaches

The most flexible approach may involve supporting multiple dependency integration modes simultaneously. Advanced users could choose the mode that best fits their development workflow and deployment requirements.

A detection-based system could automatically choose appropriate integration modes based on available dependencies. If pre-built dependencies are available, use them directly. If source dependencies are present (through submodules or manual checkout), integrate them appropriately. If no dependencies are available, fall back to automatic fetching and building.

This approach provides maximum flexibility but at the cost of increased implementation complexity and potential confusion about which mode is active. Clear documentation and status reporting would be essential to help users understand and control the dependency integration behavior.

### Performance Considerations

Dependency integration choices have significant implications for build performance, particularly for incremental builds during development. The super-ninja approach provides optimal incremental build performance but only works when all dependencies are built from source and their ninja files are available for integration.

For development workflows, the performance difference between integration modes can be substantial. The super-ninja approach enables ninja to optimize builds across project boundaries, while ExternalProject forces sequential builds even when parallelization would be possible.

However, for production builds or CI/CD environments, external dependency management may be preferable for reproducibility and build time predictability. The choice of integration mode should be configurable and appropriate defaults should be selected based on the detected environment.

## Alternative Integration Approaches

### Package Manager Integration

Modern C++ development increasingly relies on package managers like Conan, vcpkg, or Spack for dependency management. Integrating MOS MES with these systems could provide better dependency version management and distribution mechanisms.

Package manager integration would require developing platform packages for the supported package managers and ensuring that the platform inheritance system works correctly with package-provided dependencies. This approach could significantly simplify deployment for users already using package managers.

### Container-Based Development

Container technologies like Docker provide another approach to dependency management by encapsulating the entire development environment. A container-based approach could provide pre-built development environments with all dependencies pre-installed and configured.

Container-based development would eliminate dependency management complexity for users but at the cost of requiring container runtime dependencies and potentially limiting development workflow flexibility. This approach might be most appropriate as an optional deployment mode rather than the primary development approach.

### Build System Abstraction

Rather than tightly coupling to CMake, MOS MES could implement its own build system abstraction that generates appropriate build files for different backend systems. This approach would provide more control over the build process but at the cost of significant implementation complexity.

A build system abstraction would enable optimization opportunities that are not available when constrained to CMake's model. However, it would also require implementing and maintaining significant infrastructure that duplicates functionality available in existing build systems.

## Redistributable Package Organization

mosmes uses a revolutionary approach to package organization by structuring the source tree as the final redistributable package. This eliminates the traditional separation between source and build artifacts, making distribution trivial while solving the CMake configure-time dependency problem.

### Source-as-Distribution Architecture

The key insight is that the mosmes source tree is organized in its final redistributable structure from day one. Rather than building to temporary locations and copying files during an install step, mosmes places source files in their final distribution locations and builds outputs directly alongside them.

```
mosmes/
├── CMakeLists.txt              # Build configuration
├── dist/                       # Complete redistributable package
│   ├── cmake/                  # CMake configs (source files, in git)
│   │   ├── mosmes-config.cmake
│   │   └── mosmes-config-version.cmake
│   ├── include/                # Headers (source files, in git)
│   │   ├── common/
│   │   ├── c64/
│   │   └── apple2e/
│   ├── platforms/              # Platform source (source files, in git)
│   │   ├── c64.c
│   │   └── apple2e.c
│   └── lib/                    # Built libraries (build outputs)
│       ├── c64.a
│       └── apple2e.a
└── build/                      # Build system artifacts only
```

This structure solves the CMake configure-time problem because the CMake package config files exist as source files in their final location. When other projects use `find_package(mosmes)`, CMake finds the config files in `dist/cmake/` and they use relative paths like `${CMAKE_CURRENT_LIST_DIR}/../lib/` to locate the built libraries.

### Build Configuration for Direct Output

The build system configures CMake to place library outputs directly in their final redistributable locations within the source tree:

```cmake
# Configure outputs to go directly to final redistributable location
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/dist/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/dist/lib)

# Platform-specific library outputs
set_target_properties(c64_platform PROPERTIES
  ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/dist/lib
  OUTPUT_NAME c64
)
```

Headers and CMake config files don't need to be copied or generated because they already exist in their final locations as source files. The build process only needs to compile platform implementation source files into libraries and place them in the appropriate locations within the `dist/` structure.

### Package Distribution Process

After building, the entire `dist/` directory is a complete, self-contained redistributable package. Distribution becomes trivial:

```bash
# Create redistributable package
tar czf mosmes-sdk.tar.gz dist/

# Or create a zip file
zip -r mosmes-sdk.zip dist/
```

The distributed package contains everything needed: CMake configuration, headers, and built libraries. Users can extract the package and immediately use it with `find_package(mosmes)` by adding the extracted location to their `CMAKE_PREFIX_PATH`.

### Dependency Integration Strategy

External dependencies like picolibc and llvm-mos components could be included in the redistributable package or referenced as external requirements. For a self-contained SDK, essential components could be copied into the `dist/` structure during the build process:

```cmake
# Copy essential dependencies into redistributable structure
add_custom_command(TARGET mosmes_libraries POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    ${PICOLIBC_INSTALL_DIR}/include
    ${CMAKE_SOURCE_DIR}/dist/include/picolibc
)
```

This approach creates a completely self-contained SDK package that requires no additional dependency management by end users.

### Version Control Considerations

The `dist/lib/` directory (containing built libraries) should be excluded from version control since it contains build artifacts. However, all other contents of `dist/` are source files that should be committed to the repository:

```gitignore
# Exclude built libraries but keep source structure
dist/lib/
build/
```

This ensures that the redistributable structure is maintained in version control while keeping build artifacts out of the repository. Developers checking out the source get the complete redistributable structure and only need to run the build to populate the library directory.

## Implementation Priorities

The vector system implementation should be addressed first, as it affects the user interface design and has implications for platform integration. The dependency integration approach should be finalized before significant implementation work begins, as it affects the overall architecture and development workflow.

The redistributable output organization should be designed early in the implementation process, as it affects how targets are configured and where outputs are placed. This design impacts both the build system architecture and the user experience for downstream projects.

The super-ninja integration should be treated as an advanced feature that is implemented after the basic system is functional. This approach ensures that users can benefit from mosmes even if the super-ninja mode is not available in their environment.