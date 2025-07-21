# mosmess - MOS Multi-platform Embedded SDK

## Introduction

The mosmess SDK is a comprehensive development framework designed to simplify cross-platform development for MOS 6502 targets. Rather than forcing developers to manage separate toolchains, include paths, and library configurations for each target platform, mosmess provides a unified build system that leverages the existing llvm-mos compiler infrastructure and picolibc embedded C library to create a cohesive development experience.

The fundamental insight behind mosmess is that developing for various 6502-based platforms should not require separate compilers or drastically different development workflows. Whether targeting a Commodore 64, Apple IIe, NES, or any other MOS 6502 system, the underlying compiler (mos-clang) remains the same. What changes are the include directories, compiler definitions, linked libraries, and memory layouts specific to each platform. mosmess abstracts these differences through a clean, composable build system that allows developers to express their intent at a high level while automatically handling the low-level details.

## Getting Started

[TODO: Add basic setup and usage instructions]

## Documentation

For detailed technical information, see:
- [Design Documentation](doc/design.md) - Architecture and build philosophy
- [Prerequisites System](doc/prerequisites-new.md) - Toolchain bootstrapping
- [Development Guidelines](doc/CLAUDE.md) - Implementation guidance

