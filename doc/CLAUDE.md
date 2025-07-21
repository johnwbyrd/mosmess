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

### Prerequisites System for Toolchain Bootstrapping

A critical component of mosmess is the CMake prerequisites system, which solves the fundamental chicken-and-egg problem of building compilers and libraries before CMake's project() command can detect them. This system is essential for the MOS ecosystem where custom toolchains must often be built from source.

The prerequisites system operates in dual modes: immediate execution during CMake configuration (for bootstrapping) and standard CMake targets (for incremental development). This duality allows the same prerequisite definitions to work both for initial environment setup and ongoing development workflows.

Key principles for working with prerequisites:

1. **Configure-time execution is blocking**: When prerequisites build during configuration, CMake waits for completion. This is intentional - the tools must exist before project() runs.

2. **Dual dependency tracking**: Prerequisites can use simple stamp files or detailed file dependency tracking. Use stamps for stable steps, file tracking for active development.

3. **Step-based architecture**: Each prerequisite follows the download → configure → build → install → test pipeline, with later steps depending on earlier ones.

4. **Integration with platforms**: Prerequisites build the tools and libraries that platform definitions reference, creating a complete bootstrapped environment.

### Dependency Integration Philosophy

The relationship between mosmess and its external dependencies (llvm-mos and picolibc) is now solved through the prerequisites system. This approach accommodates different user preferences while maintaining build correctness:

- **External dependencies**: Users provide pre-built toolchains, mosmess finds them via CMAKE_PREFIX_PATH
- **Prerequisites-based**: Users specify prerequisites that build the toolchain during configuration
- **Mixed approach**: Some dependencies external, others built via prerequisites

Each mode has different trade-offs in terms of build reproducibility, system requirements, and development workflow. The prerequisites system makes the integrated approach practical by handling the complex bootstrap sequencing automatically.

## Technical Implementation Details

### CMake Property Propagation Mechanics

You must have a precise understanding of how CMake properties flow through target dependencies. Include directories, compile definitions, and link libraries propagate through INTERFACE properties in dependency order. This means that when target A links to target B, A receives B's INTERFACE properties. If B links to C, then A transitively receives C's INTERFACE properties as well.

The ordering of property propagation is crucial for understanding how platform inheritance works. Properties are appended in dependency order, which means that more specific platforms can override or extend properties from more general platforms. This natural ordering ensures that platform hierarchies work intuitively without requiring complex override mechanisms.

When debugging property propagation issues, remember that CMake provides excellent introspection capabilities. You can examine the final property values on any target to understand how inheritance chains resolved. This makes the system much more debuggable than custom inheritance implementations.

### Prerequisites and Build System Integration

The prerequisites system enables sophisticated dependency management while respecting build system boundaries:

1. **Configuration-time toolchain assembly**: Prerequisites can build compilers, libraries, and tools before the main project configures. This solves the detection problem cleanly.

2. **Build-time integration**: The same prerequisites create standard CMake targets that integrate with incremental builds and dependency tracking.

3. **Cross-build-system support**: Prerequisites can invoke CMake, Meson, Make, or any build system to compile dependencies, then make the results available to the main mosmess build.

The key insight is that prerequisites operate at a higher level than individual build systems. They coordinate between build systems rather than trying to make one understand another's internals.

### Cross-Project Dependency Management

When implementing cross-project dependencies through prerequisites, focus on coarse-grained ordering constraints. Prerequisites handle entire projects as units - llvm-mos builds completely before picolibc begins, and picolibc builds completely before mosmess platform libraries.

Each prerequisite maintains correct internal dependencies through its native build system. The prerequisites layer only ensures proper ordering between complete projects, not micromanagement within projects.

## User Experience Considerations

### Simplicity Through Powerful Abstractions

The user-facing API should hide the underlying complexity while providing full access to the system's capabilities. Users should be able to express their intent at a high level - specifying source files, target platforms, and build vectors - without needing to understand the implementation details of property inheritance, target multiplication, or prerequisite bootstrapping.

However, the system should also provide escape hatches for users with unusual requirements. The platform and vector systems handle the majority of use cases through composition, and prerequisites handle most toolchain scenarios, but users should always be able to fall back to manual approaches when necessary.

### Documentation and Mental Models

When documenting mosmess, emphasize the conceptual model rather than implementation details. Users need to understand:

1. **Platform inheritance** as a mental model, not INTERFACE libraries as an implementation
2. **Vector composition** as orthogonal build variations, not nested loops
3. **Prerequisites** as toolchain bootstrapping, not the dual execution mechanics

The documentation should provide clear examples that demonstrate the system's capabilities without overwhelming users with options. Start with simple single-platform builds, progress to platform inheritance, introduce vector multiplication, and finally cover prerequisite-based toolchain assembly.

## Common Pitfalls and Anti-Patterns

### Over-Engineering Temptations

You will be constantly tempted to add features that seem useful but violate the system's core principles. Resist the urge to create complex configuration systems, elaborate plugin architectures, or sophisticated code generation mechanisms. The power of mosmess comes from its simplicity and adherence to existing CMake patterns.

When users request features that seem to require significant new infrastructure, first examine whether the requirement can be met through composition of existing capabilities. Most requests can be satisfied by defining new platforms, vectors, or prerequisites rather than extending the core system.

### Build System Boundary Violations

Be extremely careful about respecting build system boundaries. CMake should not try to directly manage Meson builds, Meson should not attempt to parse CMake files, and so on. Each build system should operate within its domain and coordinate with others through well-defined interfaces.

The prerequisites system works because it operates at the coordination level, not the implementation level. It invokes build systems as black boxes and consumes their outputs, rather than trying to understand their internals.

### Property Propagation Assumptions

Do not assume that property propagation always works as expected. CMake's property system is powerful but has edge cases and limitations. Always test inheritance chains thoroughly and provide clear error messages when property propagation fails.

Remember that different types of properties propagate differently. Include directories and compile definitions propagate transitively, but some properties do not. Link libraries propagate but with complex rules about visibility and ordering.

### Prerequisites Execution Assumptions

Do not assume that prerequisites will execute quickly or silently. Building compilers can take hours and produce massive amounts of output. Design the system to handle long-running prerequisites gracefully:

1. **Progress indication**: Users need to know that progress is happening
2. **Log management**: Capture verbose output appropriately
3. **Failure recovery**: Clean up incomplete builds when steps fail
4. **Incremental behavior**: Avoid rebuilding unnecessarily

## Development Workflow

### Incremental Development Strategy

mosmess should be developed incrementally, starting with basic platform support and gradually adding more sophisticated features. The suggested order is:

1. **Basic INTERFACE library platforms** - Core property propagation
2. **Platform inheritance** - Parent-child platform relationships
3. **Vector multiplication** - Build variation support
4. **Prerequisites integration** - Toolchain bootstrapping
5. **Advanced features** - Custom vectors, complex inheritance trees

Each development increment should be fully functional and testable. Users should be able to adopt mosmess with basic features and upgrade to more advanced capabilities as needed.

### Testing and Validation

Testing mosmess requires attention to both functional correctness and performance characteristics:

**Functional testing should verify:**
- Platform inheritance works correctly
- Vector multiplication generates appropriate targets
- Prerequisites build and integrate properly
- Dependency tracking (stamps and file-based) functions correctly

**Performance testing should focus on:**
- Build system generation time with many platforms/vectors
- Incremental build behavior
- Prerequisites build time and caching effectiveness

### Community and Ecosystem Development

mosmess is designed to be extended by the community through platform, vector, and prerequisite contributions. The architecture should make it easy for community members to add support for new platforms or define reusable toolchain prerequisites without requiring changes to the core system.

Consider how platforms and prerequisites might be packaged and shared, and ensure that the system can discover and integrate community contributions smoothly.

## Long-Term Evolution

### Adaptation to Ecosystem Changes

As the MOS development ecosystem evolves, mosmess must be able to adapt without requiring architectural changes. The emphasis on leveraging existing CMake mechanisms and the prerequisites system's build-system-agnostic approach ensures compatibility with future changes.

Monitor developments in the broader embedded development community for concepts that might be applicable to mosmess. Cross-compilation support, dependency management practices, and build system innovations in other ecosystems may provide insights for mosmess evolution.

### Technology Migration Strategies

Be prepared for the possibility that underlying technologies may change over time. The architecture should be designed to accommodate such changes without requiring complete rewrites.

The key is maintaining clear separation of concerns:
- **Conceptual model**: Platforms, vectors, inheritance, prerequisites
- **Implementation mechanisms**: INTERFACE libraries, target multiplication, dual execution
- **Build system interfaces**: How we invoke CMake, Meson, Make, etc.

As long as the conceptual model remains stable, implementation details can evolve as needed.