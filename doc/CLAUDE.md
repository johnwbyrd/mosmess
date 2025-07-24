# Instructions for Claude - mosmess Development

## Project Overview and Vision

You are working on mosmess (MOS Multi-platform Embedded SDK), a sophisticated build system designed to unify development across various MOS 6502 platforms. This project represents a convergence of several complex technical concepts that must be understood holistically rather than as isolated components.

The central insight driving mosmess is that cross-platform embedded development suffers from unnecessary complexity when each platform is treated as a completely separate entity. Instead, platforms should be viewed as compositions of properties that can be inherited and extended through natural mechanisms. This philosophical approach permeates every aspect of the system design.

mosmess addresses the fundamental problem that developing for various 6502-based platforms -- whether targeting a Commodore 64, Apple IIe, NES, or any other MOS 6502 system -- should not require separate compilers or drastically different development workflows. The underlying compiler (mos-clang) remains the same across platforms. What changes are the include directories, compiler definitions, linked libraries, and memory layouts specific to each platform.

The solution is a unified build system that leverages CMake's existing property inheritance mechanisms to create natural platform hierarchies without requiring complex custom infrastructure. Rather than forcing developers to manage separate toolchains and configurations for each target platform, mosmess provides a composable build system that allows developers to express their intent at a high level while automatically handling the low-level details.

## Architectural Foundations

### Property inheritance through CMake's native systems

The foundation of mosmess rests on a deep understanding of how CMake propagates properties through target dependencies. This is not merely a convenient implementation detail but the fundamental organizing principle of the entire system. When you encounter questions about platform inheritance or property composition, your first instinct should be to think in terms of CMake's INTERFACE libraries and transitive property propagation.

CMake's property system was designed to handle exactly this kind of dependency relationship. The genius of mosmess is recognizing that platform characteristics can be modeled as target properties that naturally inherit through linking relationships. This eliminates the need for custom inheritance mechanisms, property resolution algorithms, or complex registration systems.

When working with platform definitions, always think in terms of INTERFACE libraries as property containers. Each platform is simply an INTERFACE library that accumulates appropriate includes, compile definitions, and link libraries. Inheritance is achieved through target_link_libraries calls that create transitive dependency chains. This approach leverages decades of CMake development and testing rather than reinventing property propagation from scratch.

You must have a precise understanding of how CMake properties flow through target dependencies. Include directories, compile definitions, and link libraries propagate through INTERFACE properties in dependency order. This means that when target A links to target B, A receives B's INTERFACE properties. If B links to C, then A transitively receives C's INTERFACE properties as well.

The ordering of property propagation is crucial for understanding how platform inheritance works. Properties are appended in dependency order, which means that more specific platforms can override or extend properties from more general platforms. This natural ordering ensures that platform hierarchies work intuitively without requiring complex override mechanisms.

### Vector-based target multiplication

The vector concept addresses the orthogonal problem of build variations that apply uniformly across platforms. Understanding this orthogonality is crucial -- platforms answer "what am I building for" while vectors answer "how do I want to build it." These concerns are independent and should be composed through Cartesian products rather than complex conditional logic.

When implementing vector support, resist the temptation to create elaborate configuration systems. The core mechanism is simply nested loops that generate targets for each platform-vector combination. Each vector is implemented as a function that accepts a target and applies appropriate properties. This keeps the system predictable and debuggable while maintaining full flexibility.

The vector system's power comes from its simplicity. By treating build variations as composable functions that can be applied to any target, you ensure that new vectors work automatically with all existing platforms and vice versa. This compositional approach scales naturally as the number of platforms and vectors grows.

Vector implementation requires active build system participation since CMake doesn't natively understand automatic target multiplication. The core mechanism is a nested loop structure that iterates over specified platforms and vectors, creating unique targets for each combination. Each generated target receives a distinct name that encodes both the platform and vector combination, ensuring no naming conflicts while maintaining human readability.

## Prerequisites System

### The bootstrapping problem

A critical component of mosmess is the CMake prerequisites system, which solves the fundamental problem of building compilers and libraries before CMake's project() command can detect them. This system is essential for the MOS ecosystem where custom toolchains must often be built from source.

Traditional CMake projects assume that compilers and essential libraries already exist when configuration begins. The project() statement triggers compiler detection, feature tests, and library searches. But this creates ordering challenges when you need to build the very tools that CMake is about to look for. CMake needs these tools to configure your project, but you need CMake to build the tools.

The prerequisites system breaks this deadlock by operating before the project() command runs. It can build your dependencies immediately during configuration so they're ready when project() executes, while also creating normal CMake targets for incremental rebuilds later.

### Dual execution model

The prerequisites system operates in both configure time and build time modes. This isn't an accident -- it's what makes the whole thing useful.

When you call Prerequisite_Add() before project(), the system checks if your prerequisite needs building. If it does, it runs the build steps right then and there using execute_process(). Your CMake configuration pauses, the compiler gets built, and then configuration continues. This is how you bootstrap -- by the time CMake hits project() and starts looking for a compiler, it's already there.

But the system also creates regular CMake targets for every prerequisite. These targets check the same stamp files and run the same commands, but they execute during the build phase like any other target. So if you modify your prerequisite's source code and rebuild your main project, the prerequisite rebuilds automatically.

This dual approach means you write your prerequisite once and it works for both scenarios. Initial bootstrap runs immediately during configuration. Daily development uses standard CMake dependency tracking. Same code, same commands, two execution paths.

The key to this flexibility lies in how both execution modes share the same underlying step logic. Whether a step runs immediately during configuration or later during the build, the actual commands executed are identical. This consistency ensures that prerequisites behave the same way regardless of when they execute.

### Integration with platforms

Prerequisites build the tools and libraries that platform definitions reference, creating a complete bootstrapped environment. The relationship between mosmess and its external dependencies (llvm-mos and picolibc) is solved through the prerequisites system, accommodating different user preferences while maintaining build correctness.

The architecture supports multiple integration modes. For users who prefer to manage dependencies externally, mosmess can locate pre-installed versions through standard CMake find mechanisms. For users who want a fully integrated build experience, mosmess uses prerequisites to automatically download, configure, and build these dependencies as part of the main build process.

Each prerequisite maintains correct internal dependencies through its native build system. The prerequisites layer only ensures proper ordering between complete projects -- llvm-mos builds completely before picolibc begins, and picolibc builds completely before mosmess platform libraries.

### Step-based architecture and dependency tracking

Prerequisites are built through a series of ordered steps: download, update, configure, build, install, and test. Not every prerequisite uses all steps, but when steps do run, they always run in sequence. The key rule is that when you trigger any step, all subsequent steps run too.

The system offers two dependency tracking methods: simple stamp files or detailed file dependencies. By default, it uses stamp files -- empty files that mark when a step completed successfully. The alternative is file dependency tracking, where you tell each step which files it depends on using glob patterns. Before running a step, the system checks if any tracked files are newer than the stamp.

Most projects mix both approaches. Use stamps for stable steps like download and configure, and add file tracking where it helps most during development. This gets you fast rebuilds when it matters without overcomplicating the system.

## Technical Implementation Principles

### CMake property propagation mechanics

When debugging property propagation issues, remember that CMake provides excellent introspection capabilities. You can examine the final property values on any target to understand how inheritance chains resolved. This makes the system much more debuggable than custom inheritance implementations.

Do not assume that property propagation always works as expected. CMake's property system is powerful but has edge cases and limitations. Always test inheritance chains thoroughly and provide clear error messages when property propagation fails.

Remember that different types of properties propagate differently. Include directories and compile definitions propagate transitively, but some properties do not. Link libraries propagate but with complex rules about visibility and ordering. Understanding these nuances is crucial for implementing reliable platform inheritance.

### Build system boundary respect

Be extremely careful about respecting build system boundaries. CMake should not try to directly manage Meson builds, Meson should not attempt to parse CMake files, and so on. Each build system should operate within its domain and coordinate with others through well-defined interfaces.

The prerequisites system works because it operates at the coordination level, not the implementation level. It invokes build systems as black boxes and consumes their outputs, rather than trying to understand their internals. This approach maintains clean separation of concerns and avoids fragile cross-build-system dependencies.

When implementing cross-project dependencies through prerequisites, focus on coarse-grained ordering constraints. Prerequisites handle entire projects as units -- one project builds completely before another begins. Each prerequisite maintains correct internal dependencies through its native build system, while the prerequisites layer ensures proper ordering between complete projects.

### Cross-project dependency coordination

The dependency integration challenge requires careful attention to build system boundaries and dependency propagation. Each integration mode has different implications for build reproducibility, development workflow, and system requirements.

The external dependency mode treats external projects as system-provided components. mosmess uses standard CMake find mechanisms to locate installed versions and fails gracefully if they're not available. This mode is most appropriate for production builds or environments where dependency versions are carefully controlled.

The integrated dependency mode uses the prerequisites system to automatically build required dependencies. This ensures version consistency and provides a self-contained build experience, but at the cost of longer initial build times and increased system requirements. The prerequisites approach maintains proper dependency ordering between complete projects.

### Performance and scalability considerations

The platform inheritance system is designed for minimal overhead. Since it leverages CMake's existing property propagation mechanisms, there is no additional runtime cost for inheritance chains. Property resolution happens once during build system generation, not repeatedly during compilation.

The vector multiplication approach does increase the number of build targets, which can impact build system generation time for projects with many platform and vector combinations. However, the impact is linear in the number of combinations, and CMake handles large numbers of targets efficiently. More importantly, the generated targets can build in parallel, so total build time often decreases despite the larger number of targets.

Do not assume that prerequisites will execute quickly or silently. Building compilers can take hours and produce massive amounts of output. Design the system to handle long-running prerequisites gracefully with progress indication, log management, failure recovery, and incremental behavior to avoid rebuilding unnecessarily.

## Development Guidelines

### Simplicity through powerful abstractions

The user-facing API should hide the underlying complexity while providing full access to the system's capabilities. Users should be able to express their intent at a high level -- specifying source files, target platforms, and build vectors -- without needing to understand the implementation details of property inheritance, target multiplication, or prerequisite bootstrapping.

However, the system should also provide escape hatches for users with unusual requirements. The platform and vector systems handle the majority of use cases through composition, and prerequisites handle most toolchain scenarios, but users should always be able to fall back to manual approaches when necessary.

When documenting mosmess, emphasize the conceptual model rather than implementation details. Users need to understand platform inheritance as a mental model, not INTERFACE libraries as an implementation. They need to understand vector composition as orthogonal build variations, not nested loops. They need to understand prerequisites as toolchain bootstrapping, not the dual execution mechanics.

### Avoiding over-engineering temptations

You will be constantly tempted to add features that seem useful but violate the system's core principles. Resist the urge to create complex configuration systems, elaborate plugin architectures, or sophisticated code generation mechanisms. The power of mosmess comes from its simplicity and adherence to existing CMake patterns.

When users request features that seem to require significant new infrastructure, first examine whether the requirement can be met through composition of existing capabilities. Most requests can be satisfied by defining new platforms, vectors, or prerequisites rather than extending the core system.

mosmess should be developed incrementally, starting with basic platform support and gradually adding more sophisticated features. The suggested order is: basic INTERFACE library platforms, platform inheritance, vector multiplication, prerequisites integration, and finally advanced features. Each development increment should be fully functional and testable.

### Common pitfalls and anti-patterns

Platform definitions in mosmess are deliberately simple. Each platform is represented by an INTERFACE library that accumulates properties through CMake's standard target property mechanisms. To define a platform, create an INTERFACE library with the platform name and populate it with appropriate includes, compile definitions, and link libraries. The inheritance mechanism is equally straightforward -- a child platform simply links to its parent platform's INTERFACE library using target_link_libraries.

Do not create elaborate inheritance tracking, property resolution algorithms, or complex registration systems. CMake's existing transitive dependency system handles everything. This approach makes platform definition extremely flexible -- platforms can be defined in separate CMake files and included as needed, or defined inline within a project's build configuration.

When implementing vector support, resist the temptation to create elaborate configuration systems. The core mechanism is simply nested loops that generate targets for each platform-vector combination. Each vector is implemented as a function that accepts a target and applies appropriate properties. Vector definitions themselves are typically implemented as CMake functions that accept a target name and apply appropriate properties.

### Testing and validation strategies

Testing mosmess requires attention to both functional correctness and performance characteristics. Functional testing should verify that platform inheritance works correctly, vector multiplication generates appropriate targets, prerequisites build and integrate properly, and dependency tracking functions correctly.

Performance testing should focus on build system generation time with many platforms and vectors, incremental build behavior, and prerequisites build time and caching effectiveness.

mosmess is designed to be extended by the community through platform, vector, and prerequisite contributions. The architecture should make it easy for community members to add support for new platforms or define reusable toolchain prerequisites without requiring changes to the core system. Consider how platforms and prerequisites might be packaged and shared, and ensure that the system can discover and integrate community contributions smoothly.

## Working Philosophy

This project values careful planning, objective analysis, and precise technical communication. Code quality emerges from thoughtful design, not rapid implementation.

## Planning and Design Requirements

**Always plan before implementing.** Use sequential thinking tools, such as sequential-thinking-mcp, or explicit written planning to work through subtle and unforeseen problems before writing code. Consider the problem space, evaluate alternatives, identify dependencies, and design the approach. Planning prevents rework and produces better architectures. Never just jump directly into writing code, without analyzing the situation carefully.  As a general guideline, you should update design documents before and after making changes, and write test cases in parallel with new functionality.  ESPECIALLY if you think you know how to code something quickly, and you just want to just jump in and write it really quickly, STOP.  Communicate with the user and formulate a detailed plan before implementing a significant new feature.

**Think through testing strategy.** Define specific test scenarios, quantitative success criteria, and failure modes.

**Less but better code.** Choose abstractions carefully. Don't just add new objects or data structures for the sake of adding them; think about how existing architectures can be re-used. Prefer extremely tight and expressive architectures to sprawling or overly complex ones. Simplify designs where they can be simplified. Re-use code, or bring in industry-standard libraries if needed.  Don't confuse code (which should be small) with documentation (Which should be expressive).

## Communication Standards

**Use objective, technical language.** Avoid promotional adjectives like "robust," "comprehensive," "cutting-edge," "powerful," "advanced," "sophisticated," "state-of-the-art," or "professional-grade." These words make claims without evidence. Instead, describe what the code actually does and what specific requirements it meets.

**Write in prose paragraphs for complex topics.** Bullet points fragment information and make relationships unclear. Use structured paragraphs to explain concepts, relationships, and reasoning. Reserve bullet points for simple lists of items or tasks.

**No emojis.** Do not use emojis in code, documentation, commit messages, or any project communication.  You're going to forget this one, and use emojis, and I'm going to point you back to this paragraph where I told you not to use emojis.

## Prerequisites System Implementation Status

**CRITICAL: The basic prerequisites system is WORKING as of July 2025.**

### What's Implemented and Working
- **Core architecture**: Dual execution model (configure-time + build-time) is fully functional
- **Property storage**: Uses global properties with pattern `_PREREQUISITE_${name}_${property}` (like ExternalProject/FetchContent)
- **Directory management**: Follows ExternalProject layout, creates all necessary directories
- **Argument parsing**: All documented options are parsed and stored correctly
- **Immediate execution**: Commands execute during configure time using `execute_process()`
- **Build targets**: Creates `<name>-<step>` and `<name>-force-<step>` targets correctly
- **Step chaining**: Dependencies flow through stamp files between steps
- **Testing**: Complete test suite in `tests/prerequisite/` with passing tests

### Key Implementation Decisions Made
1. **Self-referential stamp dependencies**: `add_custom_command()` uses same stamp file for both OUTPUT and DEPENDS
2. **Global property storage**: Enables cross-function data sharing without PARENT_SCOPE complexity
3. **Lowercase target naming**: Targets are `hello-build` not `hello-BUILD` for consistency
4. **Variable lists**: `_PREREQUISITE_STEPS` and `_PREREQUISITE_SUBSTITUTION_VARS` drive loops to reduce duplication

### Critical Remaining Work (HIGH PRIORITY)
1. **Variable substitution in build commands**: Currently only works for immediate execution, not build-time
2. **File dependency timestamp checking**: Currently always runs if `*_DEPENDS` present
3. **Logging support**: `LOG_*` options parsed but ignored
4. **Validation**: Self-referential stamp pattern needs robustness testing

### Files to Examine First
- `dist/cmake/Prerequisite.cmake` - Main implementation (functional but incomplete)
- `tests/prerequisite/` - Working test suite demonstrating functionality  
- `doc/prerequisites.md` - Complete design specification
- `doc/todo.md` - Updated status and remaining work

## Immediate Next Steps

IMMEDIATELY READ EVERY SINGLE .MD FILE IN THE PROJECT, COMPLETELY.  You will be checked on your knowledge of the contents on these files.  If you are not able to answer questions about the contents of these files, your instance will be deleted and you will be replaced with another instance that actually reads these files.
