# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This project "helloworld.assembler" is focused on assembly language programming specifically for the Mac Silicon (ARM64/AArch64) ecosystem. It will likely involve creating a simple assembler or working with assembly code for Apple Silicon processors.

## Getting Started

For Mac Silicon development:

1. Use `as` (the system assembler) or `clang` to assemble ARM64 assembly code:
   ```
   as -arch arm64 source.s -o object.o
   ```

2. Link with `ld` or `clang`:
   ```
   ld -o executable object.o -lSystem -syslibroot `xcrun -sdk macosx --show-sdk-path` -e _start -arch arm64
   ```
   
   Or with clang:
   ```
   clang -o executable object.o
   ```

## ARM64 Assembly Development

- Use ARM64 assembly syntax for Mac Silicon
- System calls use the macOS ARM64 calling convention:
  - System call number in x16
  - Arguments in x0-x7
  - Return value in x0

## Architecture

Key components for an ARM64 assembler on Mac Silicon:
- Parser for ARM64 instruction set
- Support for Apple-specific directives
- Handling of Mac Silicon memory model
- Integration with macOS system calls

## Testing

Test assembly code with the following command:
```
./executable
```

For debugging:
```
lldb ./executable
```