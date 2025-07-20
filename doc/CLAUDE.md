# Instructions for Claude - mosmess Development

## Project Context and Vision

You are working on mosmess (MOS Multi-platform Embedded SDK), a sophisticated build system designed to unify development across various MOS 6502 platforms. This project represents a convergence of several complex technical concepts that must be understood holistically rather than as isolated components.

The central insight driving mosmess is that cross-platform embedded development suffers from unnecessary complexity when each platform is treated as a completely separate entity. Instead, platforms should be viewed as compositions of properties that can be inherited and extended through natural mechanisms. This philosophical approach permeates every aspect of the system design.

## Core Architectural Principles

### Property Inheritance Through CMake's Native Systems

The foundation of mosmess rests on a deep understanding of how CMake propagates properties through target dependencies. This is not merely a convenient implementation detail but the fundamental organizing principle of the entire system. When you encounter questions about platform inheritance or property composition, your first instinct should be to think in terms of CMake's INTERFACE libraries and transitive property propagation.

Remember that CMake's property system was designed to handle exactly this kind of dependency relationship. The genius of mosmess is recognizing that platform characteristics can be modeled as target properties that naturally inherit through linking relationships. This eliminates the need for custom inheritance mechanisms, property resolution algorithms, or complex registration systems.

When working with platform definitions, always think in terms of INTERFACE libraries as property containers. Each platform is simply an INTERFACE library that accumulates appropriate includes, compile definitions, and link libraries. Inheritance is achieved through target_link_libraries calls that create transitive dependency chains. This approach leverages decades of CMake development and testing rather than reinventing property propagation from scratch.

### Vector-Based Target Multiplication

The vector concept addresses the orthogonal problem of build variations that apply uniformly across platforms. Understanding this orthogonality is crucial - platforms answer "what am I building for" while vectors answer "how do I want to build it." These concerns are independent and should be composed through Cartesian products rather than complex conditional logic.

When implementing vector support, resist the temptation to create elaborate configuration systems. The core mechanism is simply nested loops that generate targets for each platform-vector combination. Each vector is implemented as a function that accepts a target and applies appropriate properties. This keeps the system predictable and debuggable while maintaining full flexibility.

The vector system's power comes from its simplicity. By treating build variations as composable functions that can be applied to any target, you ensure that new vectors work automatically with all existing platforms and vice versa. This compositional approach scales naturally as the number of platforms and vectors grows.

### Dependency Integration Philosophy

The relationship between mosmess and its external dependencies (llvm-mos and picolibc) represents a sophisticated approach to multi-build-system integration. You must understand that different users have different preferences for dependency management, and the system should accommodate all reasonable approaches rather than forcing a single solution.

The external dependency mode recognizes that many users prefer to manage toolchain dependencies through system package managers or manual installation. The integrated dependency mode serves users who want a completely self-contained build experience. The super-ninja mode provides optimal incremental build performance for active SDK development.

Each mode has different trade-offs in terms of build reproducibility, system requirements, and development workflow. You should not advocate for one approach over others but rather ensure that all modes are well-supported and properly documented.

## Technical Implementation Details

### CMake Property Propagation Mechanics

You must have a precise understanding of how CMake properties flow through target dependencies. Include directories, compile definitions, and link libraries propagate through INTERFACE properties in dependency order. This means that when target A links to target B, A receives B's INTERFACE properties. If B links to C, then A transitively receives C's INTERFACE properties as well.

The ordering of property propagation is crucial for understanding how platform inheritance works. Properties are appended in dependency order, which means that more specific platforms can override or extend properties from more general platforms. This natural ordering ensures that platform hierarchies work intuitively without requiring complex override mechanisms.

When debugging property propagation issues, remember that CMake provides excellent introspection capabilities. You can examine the final property values on any target to understand how inheritance chains resolved. This makes the system much more debuggable than custom inheritance implementations.

### Build System Integration Strategies

The super-ninja approach represents the most technically sophisticated aspect of mosmess. You must understand that ninja's subninja mechanism allows multiple build graphs to be combined into a unified dependency system. This is not merely a convenience feature but a fundamental capability that enables optimal incremental builds across multiple projects.

**CRITICAL UNDERSTANDING: All build dependencies must be expressed at configure time, not build time.** This is the fundamental principle that makes mosmess reliable and scalable. Procedural builds where you "build X then Y" are fragile and don't scale. Instead, the complete dependency graph must be available when CMake runs.

#### Configure-Time Dependency Expression

For superninja builds, at CMake configure time we must:

1. **Configure all dependencies first**:
   - Run CMake to configure llvm-mos (generates `build/dependencies/llvm-mos/build.ninja`)
   - Run Meson to configure picolibc (generates `build/dependencies/picolibc/build.ninja`)
   - These ninja files now exist and can be referenced

2. **Generate the master ninja file**:
   - Create a master `build/superninja/build.ninja` that includes:
     ```ninja
     subninja ../dependencies/llvm-mos/build.ninja
     subninja ../dependencies/picolibc/build.ninja
     subninja ../mosmess.ninja
     ```
   - Express high-level dependencies between projects:
     ```ninja
     build picolibc-configure: phony llvm-mos-install
     ```

3. **Make dependencies visible**: The master ninja file gives complete visibility into all dependencies across all projects. We can depend on specific targets like "llvm-mos-install" from our build.

This approach means that when the user runs `ninja -C build/superninja`, ninja has complete knowledge of every dependency across all three projects and can optimally schedule builds.

#### CMake-Only Builds

When not using superninja, we lose fine-grained visibility:
- FetchContent must handle both llvm-mos (CMake-based) and picolibc (Meson-based)
- CMake cannot see inside Meson's build graph
- Dependencies are coarser and builds less optimal
- Still functional but not as efficient as superninja

The key insight is that ninja operates at a lower level than individual build system generators. While CMake, Meson, and other tools generate ninja files, ninja itself is responsible for executing the actual build commands. By combining ninja files from multiple sources at configure time, you create a build system with complete dependency visibility.

However, this approach only works when all dependencies are built from source in a controlled layout. When users provide external dependencies, the super-ninja approach becomes inapplicable, and you must fall back to traditional CMake dependency management. The system should detect which mode is appropriate and adapt accordingly.

### Cross-Project Dependency Management

When implementing cross-project dependencies in the super-ninja mode, resist the urge to enumerate fine-grained dependencies between individual files or targets. The complexity of such an approach would quickly become unmaintainable as projects evolve.

Instead, focus on coarse-grained ordering constraints between entire projects. The master ninja file should declare that picolibc as a whole depends on llvm-mos as a whole, and mosmess as a whole depends on picolibc as a whole. Each individual project maintains correct internal dependencies through its native build system.

This approach leverages the fact that build systems are already optimized for dependency tracking within their domains. The super-ninja layer only needs to coordinate between domains, not micromanage within them.

## User Experience Considerations

### Simplicity Through Powerful Abstractions

The user-facing API should hide the underlying complexity while providing full access to the system's capabilities. Users should be able to express their intent at a high level - specifying source files, target platforms, and build vectors - without needing to understand the implementation details of property inheritance or target multiplication.

However, the system should also provide escape hatches for users with unusual requirements. The platform and vector systems handle the majority of use cases through composition, but users should always be able to fall back to manual target creation and property application when necessary.

### Documentation and Mental Models

When documenting mosmess, emphasize the conceptual model rather than implementation details. Users need to understand platform inheritance and vector composition as mental models, not CMake INTERFACE libraries and nested loops as implementation techniques.

The documentation should provide clear examples that demonstrate the system's capabilities without overwhelming users with options. Start with simple single-platform builds, progress to platform inheritance, then introduce vector multiplication. Each concept should build naturally on the previous ones.

## Common Pitfalls and Anti-Patterns

### Over-Engineering Temptations

You will be constantly tempted to add features that seem useful but violate the system's core principles. Resist the urge to create complex configuration systems, elaborate plugin architectures, or sophisticated code generation mechanisms. The power of mosmess comes from its simplicity and adherence to existing CMake patterns.

When users request features that seem to require significant new infrastructure, first examine whether the requirement can be met through composition of existing capabilities. Most requests can be satisfied by defining new platforms or vectors rather than extending the core system.

### Build System Boundary Violations

Be extremely careful about respecting build system boundaries. CMake should not try to directly manage Meson builds, ninja should not attempt to parse CMake files, and so on. Each build system should operate within its domain and coordinate with others through well-defined interfaces.

The super-ninja approach works because it operates at ninja's level, below the individual build system generators. It does not attempt to make one build system understand another's internals.

### Property Propagation Assumptions

Do not assume that property propagation always works as expected. CMake's property system is powerful but has edge cases and limitations. Always test inheritance chains thoroughly and provide clear error messages when property propagation fails.

Remember that different types of properties propagate differently. Include directories and compile definitions propagate transitively, but some properties do not. Link libraries propagate but with complex rules about visibility and ordering.

## Development Workflow

### Incremental Development Strategy

mosmess should be developed incrementally, starting with basic platform support and gradually adding more sophisticated features. Begin with simple INTERFACE library platforms, add inheritance support, then introduce vector multiplication. The super-ninja integration should be developed last, as it depends on having a working CMake-based system first.

Each development increment should be fully functional and testable. Users should be able to adopt mosmess with basic features and upgrade to more advanced capabilities as needed.

### Testing and Validation

Testing mosmess requires attention to both functional correctness and performance characteristics. Functional tests should verify that platform inheritance works correctly, vector multiplication generates appropriate targets, and dependency integration modes behave properly.

Performance testing should focus on build system generation time and incremental build behavior. The system should scale well with increasing numbers of platforms and vectors, and the super-ninja mode should provide measurable improvements for incremental builds.

### Community and Ecosystem Development

mosmess is designed to be extended by the community through platform and vector contributions. The architecture should make it easy for community members to add support for new platforms without requiring changes to the core system.

Platform definitions should be self-contained and distributable. Consider how platforms might be packaged and shared, and ensure that the system can discover and integrate community-contributed platforms smoothly.

## Long-Term Evolution

### Adaptation to Ecosystem Changes

As the MOS development ecosystem evolves, mosmess must be able to adapt without requiring architectural changes. The emphasis on leveraging existing CMake mechanisms rather than creating custom infrastructure ensures compatibility with future CMake improvements.

Monitor developments in the broader embedded development community for concepts that might be applicable to mosmess. Cross-compilation support, dependency management practices, and build system innovations in other ecosystems may provide insights for mosmess evolution.

### Technology Migration Strategies

Be prepared for the possibility that underlying technologies may change over time. CMake itself evolves, ninja may be superseded by other build execution engines, and new build systems may emerge. The architecture should be designed to accommodate such changes without requiring complete rewrites.

The key is maintaining clear separation of concerns between the conceptual model (platforms, vectors, inheritance) and the implementation mechanisms (INTERFACE libraries, target multiplication, subninja). As long as the conceptual model remains stable, implementation details can evolve as needed.