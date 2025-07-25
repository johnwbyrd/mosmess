# mosmess Development TODO

## Current Status

**Prerequisites System:**
- ✅ Basic prerequisites system is WORKING - all tests pass
- ✅ Core functionality implemented: argument parsing, directory setup, dual execution model
- ✅ Test framework established with hello_immediate and hello_deferred tests
- ✅ Self-referential stamp file dependencies working correctly
- ✅ Property storage system using global properties with `_PREREQUISITE_${name}_${property}` pattern

## Immediate Next Steps

### 1. Prerequisites System Refinement (HIGH PRIORITY)
1. **CRITICAL: Verify immediate execution actually works** - may not be executing during configure time as expected
2. **Variable substitution in build-time commands** - currently only works for immediate execution
3. **Logging support** - `LOG_*` options are parsed but ignored
4. **Validation of circular stamp dependencies** - verify self-referential pattern is robust

### 2. Testing and Validation
- Expand test coverage for edge cases and error conditions
- ✅ Test file dependency tracking - IMPLEMENTED with proper timestamp comparison
- Validate prerequisite-to-prerequisite dependencies (DEPENDS option)
- Test variable substitution in all contexts
- **CRITICAL: Create test that proves immediate execution during configure time**

### 3. Key Implementation Notes for Future Work
- Uses global properties for cross-function data sharing (like ExternalProject/FetchContent)
- Stamp files use self-referential dependencies: OUTPUT and DEPENDS both reference same stamp file  
- Target naming: lowercase step names (`myprereq-build` not `myprereq-BUILD`)
- Directory structure follows ExternalProject layout exactly

## Longer Term Goals

### Prerequisites System Completion
- ⚠️ Complete Prerequisite_Add() with dual execution model - immediate execution may be broken
- ✅ ~~Implement stamp-based dependency tracking~~ (DONE) 
- ✅ ~~Complete file-based dependency tracking with proper timestamp comparison~~ (DONE)
- 🔄 Add comprehensive logging and error handling
- ✅ ~~Build inter-prerequisite dependency management~~ (basic implementation done)

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