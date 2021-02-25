# blah

Pet project where I intend to write a complete usable computer from as scratch as possible.
Based on the [RiSC16 ISA](https://user.eng.umd.edu/~blj/RiSC/RiSC-isa.pdf).
Written in crystal because it rules.

Quicktest:
```sh
crystal build src/cli.cr && ./cli debug --spec=specs/tty.ini examples/hello.blah
```

Rich hello world:
```
start:  movi r7 :__stack         # stack at end of ram
main:
        call :fetch r7 r6        # call main using stack r7 and return r6, save r1
        loop:
            lw r2 r6 0           # read data from ram
            beq r2 r0 :end       # Goto halt if \0
            sw r2 r0 :__io_tty_r # write data in tty
            addi r6 r6 1         # increment data ptr
        beq r0 r0 :loop          # break
        sw r6 r0 -1              # dump return value in tty
end:    halt
fetch:
        function r7 r6           # declare func called using r7 stack and r6 tmp register
        movi r1 :hello           # load the data adress in r1
        return r7 r1 r6          # return r1 using stack r7 and tmp register r6

hello:  .ascii "Hello wolrd !!"
        .ascii "garbaggggge"
```

## Components

### Top-Level
[RiSC16](./src/risc16.cr) contains the definition of the ISA.
It holds the base *Instruction* class encoding and decoding methods.

### Spec
[Spec](./src/spec.cr) is a class holding configuration for the toolchain, 
such as memory mapping informations. It can be parsed from .ini files as seen in the [specs directory](./specs).

### Assembler
The [assembler](./src/assembler/assembler.cr) module holds various class and methods used to assemble a bunch of assembly file into bitcode.

#### Statement
A statement is anything that can be assembled. It must be able to declare its expected bitcode size and write it's bitcode representation.

#### Unit
An [unit](./src/assembler/unit.cr) represent a program of a part of one. 

#### Loc
A [line of code](./src/assembler/loc.cr) represent a single line of code. 

#### Instruction
An [instruction](./src/assembler/instruction.cr) is a statement that represent a single instruction.

#### Pseudo Instruction
An [pseudo instruction](./src/assembler/pseudo/pseudo.cr) is a statement that represent a macro instruction that will resolve to multiple instructions.

#### Data
A [data staement](./src/assembler/data/data.cr) is a statement that represent raw data.

### VM

### Debugger

### CLI

## Roadmap
- [x] Write an assembler able to ouput raw bitcode
  - [x] Data statements
  - [x] Basic math in offset (absolute difference between offset for data sizes)
  - [ ] Multiple source and minimal runtime
  - [x] Predefined symbols (stack, io)
- [x] Write a dummy virtual machine that can execute this raw bitcode
  - [x] IO (kinda)
  - [x] Hello World
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
