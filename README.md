# mosmess - MOS Multi-platform Embedded SDK

## Introduction

The mosmess SDK is a comprehensive development framework designed to simplify cross-platform development for MOS 6502 targets. Rather than forcing developers to manage separate toolchains, include paths, and library configurations for each target platform, mosmess provides a unified build system that leverages the existing llvm-mos compiler infrastructure and picolibc embedded C library to create a cohesive development experience.

The fundamental insight behind mosmess is that developing for various 6502-based platforms should not require separate compilers or drastically different development workflows. Whether targeting a Commodore 64, Apple IIe, NES, or any other MOS 6502 system, the underlying compiler (mos-clang) remains the same. What changes are the include directories, compiler definitions, linked libraries, and memory layouts specific to each platform. mosmess abstracts these differences through a clean, composable build system that allows developers to express their intent at a high level while automatically handling the low-level details.

## Architectural Philosophy

### Platform Composition Through Property Inheritance

## Build Philosophy: The dist/ Directory

mosmess takes a revolutionary approach to build organization that differs from traditional CMake projects. The core principle is simple: **the `dist/` directory IS the SDK**. This directory contains everything a developer needs to create 6502 applications - both source files checked into version control and build outputs generated during compilation.

### Why dist/ Instead of Traditional Build/Install?

Traditional CMake projects separate source, build, and install directories. mosmess collapses this distinction by organizing the source tree as the final redistributable package from day one. This approach:

1. **Eliminates install steps** - No need to run `make install` or configure install prefixes
2. **Simplifies packaging** - The dist/ directory can be zipped and redistributed as-is
3. **Solves CMake timing issues** - Package config files exist at their final locations during configuration
4. **Makes development transparent** - What you see in dist/ is exactly what users get

### The dist/ vs build/ Distinction

**dist/** - Contains everything needed for 6502 development:
- Original source files (headers, CMake configs)
- Built libraries from mosmess
- Selected headers and libraries from llvm-mos
- Picolibc headers and libraries
- Platform-specific toolchain files
- Documentation and examples

**build/** - Contains only temporary build artifacts:
- CMake cache and generation files
- Object files and intermediate outputs
- Dependency build trees (llvm-mos, picolibc)
- Ninja files
- Test outputs and logs

In short: **If you need it to develop a program for the 6502, it goes in dist/. Everything else goes in build/.**

### mosmess SDK Structure

```
mosmess/
├── CMakeLists.txt              # Top-level build configuration
├── dist/                       # THE SDK - Everything needed for 6502 development
│   ├── cmake/                  # CMake integration (checked into git)
│   │   ├── mosmess-config.cmake
│   │   └── mosmess-config-version.cmake
│   ├── include/                # Headers (mixed source/generated)
│   │   ├── mosmess/            # mosmess headers (checked into git)
│   │   │   ├── common/
│   │   │   ├── c64/
│   │   │   └── apple2e/
│   │   └── picolibc/           # Copied from picolibc build
│   ├── lib/                    # All libraries (build output)
│   │   ├── mosmess/            # mosmess platform libraries
│   │   │   ├── c64.a
│   │   │   └── apple2e.a
│   │   └── picolibc/           # Copied from picolibc build
│   │       └── [arch-specific libs]
│   ├── bin/                    # Selected tools from llvm-mos (build output)
│   │   ├── mos-clang
│   │   └── mos-ld
│   └── share/                  # Resources and configs
│       └── toolchain/          # CMake toolchain files
└── build/                      # Temporary build artifacts (NOT distributed)
    ├── CMakeCache.txt          # CMake state
    ├── dependencies/           # Full dependency build trees
    │   ├── llvm-mos/           # Complete llvm-mos build
    │   └── picolibc/           # Complete picolibc build
    └── obj/                    # Object files
```

### Cleaning the Build

Because mosmess uses a non-traditional build layout with outputs in both `dist/` and `build/`, cleaning requires special consideration.

### Creating a Redistributable SDK

After building, the entire `dist/` directory is a complete, self-contained SDK that can be packaged and distributed as-is.

## Architectural Philosophy

### Platform Composition Through Property Inheritance

The core architectural principle of mosmess is that platforms are not monolithic entities but rather compositions of properties that can be inherited and extended. This concept leverages CMake's existing property propagation system to create natural inheritance hierarchies without requiring complex custom infrastructure.

Consider the relationship between different Commodore platforms. A Commodore 64 shares significant characteristics with other Commodore machines - they use similar kernel interfaces, memory-mapped I/O patterns, and development conventions. Rather than duplicating this common functionality across platform definitions, mosmess models this through inheritance. A base "commodore" platform captures the shared characteristics, while the "c64" platform inherits from commodore and adds C64-specific properties such as memory layout, hardware-specific defines, and platform libraries.

This inheritance is implemented using CMake's INTERFACE libraries as property containers. When a platform inherits from another, it literally links to the parent platform's INTERFACE library, causing CMake's transitive property system to automatically propagate includes, compile definitions, and link libraries down the inheritance chain. This approach requires no custom inheritance tracking or complex property resolution - CMake's existing dependency system handles it naturally.

### Vector-Based Target Multiplication

Beyond platform inheritance, mosmess introduces the concept of compilation vectors to handle orthogonal build variations. While platforms address "what system am I targeting," vectors address "how do I want to build it." Common vectors include debug versus release configurations, or builds with and without undefined behavior sanitization enabled.

The key insight is that these variations are independent of platform choice. Whether building for C64 or Apple IIe, the distinction between debug and release builds remains consistent. Rather than requiring developers to manually manage every combination of platform and build variant, mosmess automatically generates the Cartesian product of specified platforms and vectors.

When a developer specifies platforms C64 and Apple IIe along with vectors debug and release, mosmess automatically creates four distinct build targets: C64 debug, C64 release, Apple IIe debug, and Apple IIe release. Each target receives the appropriate combination of platform properties and vector-specific build settings, ensuring that all variations are available without manual configuration.

### Dependency Integration Strategy

A critical aspect of mosmess is how it integrates with external dependencies, specifically llvm-mos and picolibc. These projects use different build systems (CMake for llvm-mos, Meson for picolibc) but are essential components of the MOS development toolchain. mosmess must accommodate different user preferences for dependency management while maintaining build correctness and efficiency.

The architecture supports multiple integration modes. For users who prefer to manage dependencies externally, mosmess can locate pre-installed versions of llvm-mos and picolibc through standard CMake find mechanisms. For users who want a fully integrated build experience, mosmess can use CMake's ExternalProject or FetchContent systems to automatically download, configure, and build these dependencies as part of the main build process.

## Implementation Strategy

### Platform Definition and Registration

Platform definitions in mosmess are deliberately simple. Each platform is represented by an INTERFACE library that accumulates properties through CMake's standard target property mechanisms. To define a platform, developers create an INTERFACE library with the platform name and populate it with appropriate includes, compile definitions, and link libraries.

The inheritance mechanism is equally straightforward. A child platform simply links to its parent platform's INTERFACE library using target_link_libraries. This causes CMake to automatically propagate the parent's properties to any target that eventually links to the child platform. There is no need for explicit inheritance tracking, property resolution algorithms, or complex registration systems - CMake's existing transitive dependency system handles everything.

This approach also makes platform definition extremely flexible. Platforms can be defined in separate CMake files and included as needed, or they can be defined inline within a project's build configuration. New platforms can be added simply by creating new INTERFACE libraries and establishing their inheritance relationships.

### Vector Implementation and Target Generation

Vector implementation requires more active build system participation since CMake doesn't natively understand the concept of automatic target multiplication. The core mechanism is a nested loop structure that iterates over specified platforms and vectors, creating unique targets for each combination.

Each generated target receives a distinct name that encodes both the platform and vector combination, ensuring no naming conflicts while maintaining human readability. The target generation process applies platform properties through linking to the appropriate INTERFACE libraries, then applies vector-specific properties through additional CMake commands.

Vector definitions themselves are typically implemented as CMake functions that accept a target name and apply appropriate properties. For example, a "debug" vector function might add debug compile flags and link to debug versions of libraries, while a "release" vector function might enable optimization flags and strip debugging information.

### Dependency Resolution and Build Orchestration

The dependency integration challenge requires careful attention to build system boundaries and dependency propagation. Each integration mode has different implications for build reproducibility, development workflow, and system requirements.

The external dependency mode treats llvm-mos and picolibc as system-provided components. mosmess uses standard CMake find mechanisms to locate installed versions and fails gracefully if they're not available. This mode is most appropriate for production builds or environments where dependency versions are carefully controlled through external package management.

The integrated dependency mode uses CMake's ExternalProject system to automatically build required dependencies. This ensures version consistency and provides a self-contained build experience, but at the cost of longer initial build times and increased system requirements. The ExternalProject approach maintains proper dependency ordering - picolibc won't begin building until llvm-mos is complete, and mosmess platform libraries won't build until picolibc is available.

### Cross-Project Dependency Management

Cross-project dependencies are managed through CMake's standard mechanisms. When building dependencies from source, mosmess uses coarse-grained ordering constraints - picolibc as a whole depends on llvm-mos as a whole, and mosmess as a whole depends on picolibc as a whole.

This approach leverages the fact that each individual project already has correct internal dependency tracking through its native build system. For users who build dependencies externally, mosmess uses imported targets to represent externally-built components.

## User Experience Design

### Project Configuration Interface

From a user perspective, mosmess aims to make cross-platform development as simple as single-platform development. A typical project configuration might specify source files, target platforms, and desired build vectors in a clean, declarative syntax. The build system then handles all the complexity of generating appropriate targets, applying platform properties, and managing dependencies.

The user interface emphasizes composition and reuse. Developers can define custom platforms that inherit from existing ones, allowing for easy customization without losing the benefits of shared infrastructure. Similarly, custom vectors can be defined to handle project-specific build requirements while maintaining compatibility with standard platforms.

## Technical Considerations

### Build Performance and Scalability

The platform inheritance system is designed for minimal overhead. Since it leverages CMake's existing property propagation mechanisms, there is no additional runtime cost for inheritance chains. Property resolution happens once during build system generation, not repeatedly during compilation.

The vector multiplication approach does increase the number of build targets, which can impact build system generation time for projects with many platform and vector combinations. However, the impact is linear in the number of combinations, and CMake handles large numbers of targets efficiently. More importantly, the generated targets can build in parallel, so total build time often decreases despite the larger number of targets.

