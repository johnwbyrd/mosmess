# mosmess Development TODO

## Current Status

**Prerequisites System:**
- Prerequisite.cmake exists with complete documentation and stub implementations
- prerequisites.md documentation is finalized with either/or dependency tracking model clarified
- Test strategy and framework approach decided and documented in tests-prerequisite.md

## Immediate Next Steps

### 1. Prerequisites Test Framework Setup
1. Create basic test framework structure (`tests/CMakeLists.txt`, basic utils)
2. Write 1-2 simple tests against existing stubs to validate framework
3. Implement minimal Prerequisite_Add() functionality to support initial tests
4. Expand tests and implementation incrementally following the phased approach

### 2. Key Implementation Reminders
- Focus on dual execution model as the core differentiator from ExternalProject
- Each step uses either stamp tracking OR file dependencies, never both
- Variable substitution (@PREREQUISITE_*@) is critical functionality to test thoroughly
- Process isolation is essential due to project() timing sensitivity

## Longer Term Goals

### Prerequisites System Implementation
- Complete Prerequisite_Add() with dual execution model
- Implement stamp-based dependency tracking
- Implement file-based dependency tracking with glob patterns
- Add variable substitution system (@PREREQUISITE_*@ replacement)
- Build inter-prerequisite dependency management
- Add logging and error handling

### Platform and Vector Systems
- Design and implement platform inheritance through INTERFACE libraries
- Implement vector-based target multiplication
- Create platform definitions for common MOS 6502 targets
- Integrate prerequisites with platform/vector systems

### Integration and Documentation
- Create comprehensive examples showing prerequisites → platforms → vectors workflow
- Integrate with dist/ directory structure and SDK generation
- Performance testing and optimization
- User documentation and tutorials