# blah

Pet project where I intend to write a complete usable computer from as scratch as possible.
Based on the [RiSC16 ISA](# https://user.eng.umd.edu/~blj/RiSC/RiSC-isa.pdf).
Written in crystal because it rule.

## Components

### Assembler

### VM

### Debugger

### CLI

## Roadmap
- [x] Write an assembler able to ouput raw bitcode
  - [ ] Data statements
  - [ ] Static linking
- [x] Write a dummy virtual machine that can execute this raw bitcode
  - [ ] IO
  - [ ] Write a program that do something
- [x] Write a bunch of comfort utilities (CLI, barebone Debugger)
- [ ] Design and write a compiler for a small stack language
  - [ ] Write a bunch of utility functions (basic math)
- [ ] Write an OS
  - [ ] Load another program
  - [ ] Handle syscalls and barebone scheduler 
  - [ ] Syscall
  - [ ] Memory management
  - [ ] Create a more fleshed out executable file format
  - [ ] Dynamic librairies and linking
