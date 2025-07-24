# mosmess - MOS Multi-platform Embedded SDK

"It's just C." -Mosmess

## What is mosmess?

mosmess lets you write games and programs for classic 6502 computers without the usual headaches.

Instead of managing separate toolchains for each retro computer, mosmess gives you one unified build system. The same C compiler works for all platforms -- it's just the memory layouts, libraries, and hardware interfaces that differ. mosmess knows about these differences so you don't have to.

Best of all, it's just standards-compliant C17. No weird custom dialects, no "that doesn't work on our compiler" surprises. Your C code behaves the same way whether you're targeting a breadboard 6502 or your laptop.

Think of it as a modern SDK for vintage computing. You focus on writing your core logic, and mosmess takes care of making it work across different 6502 machines.

With its strong emphasis on standards compliance, mosmess is a great choice for porting existing code to your favorite 65xx target.

## How it works

mosmess is built around three core ideas:

**Platform inheritance** -- Commodore machines share common characteristics, so a C64 platform can inherit from a base Commodore platform and just add C64-specific details. No duplicate configuration.

**Automatic toolchain setup** -- mosmess can build the llvm-mos compiler and required libraries from source during project setup. No manual dependency hunting.

**Build variants** -- Want debug and release versions of your game for multiple platforms? mosmess automatically generates all the combinations you need.

## Documentation

- [Design Documentation](doc/design.md) - Architecture and build philosophy
- [Prerequisites System](doc/prerequisites.md) - Toolchain bootstrapping

