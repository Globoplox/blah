# Blah

## What is this project

This is a toy computational toolchain. It allows to compile, assemble, link, run and debug programs, without relying on existing tech.  
It use the [RiSC16](https://user.eng.umd.edu/~blj/risc/) instruction set architecture.
>  RiSC stands for Ridiculously Simple Computer, which makes sense in the context in which the instruction-set is normally used -- to teach simple organization and architecture to undergraduates who do not yet know how computers work. The architecture has a whopping 8 opcodes, uses 8 registers, and is nonetheless general enough to execute fairly sophisticated programs. This makes it a relatively useful teaching tool, as it allows students to look at computer architecture concepts from simple to advanced without the instruction-set getting in the way or cluttering up the picture.  
> -- <cite>Bruce Jacob</cite>

Doing so, it involves simple implementation of:
- A virtual machine implementing the RiSC16 ISA
- An assembler for a RiSC16 assembly language, outputing custom relocatable object files
- A linker for mergeing and linking said object files into a raw binary 
- A compiler for a rudimentary imperative C-inspired general purpose language
- A curses based debugger

This toolchain is implemented as a **pure** library.  
There are two implementation integrating this toolchain:
- A CLI based on STDIO and the local filesystem 
- A multi user web application

## Why is this project

The initial motivation is to experiment with compiler and computer architecture from scratch but without the burden of the complexity of computers. 
This is a pet project and pretext to learn and experiment.  

Since the project began to yield some (moderatly) interesting results I decided to use at as my main portfollio item and so I made it a demo project for more marketable skills and added the web application.  

## Core Concepts

The most down to earth objective one can have with this toolchain is to build and run a program.  

### Computer specification

An instruction set architecture is a description of a CPU capabilities, not a description of a full computers. 
We need some additional information to describe event the simplest computer. Since RiSC16 use [memory mapped IO](https://en.wikipedia.org/wiki/Memory-mapped_I/O_and_port-mapped_I/O) we need to define the address space of our computers.  
Address space are defined in spec files: 

*spec.ini*
```ini
[hardware.segment.ram]
kind=ram
start=0x0
size=0xffff
```

This describe a computer whith no I/O and whose full address space (from 0 to 0xffff as RiSC16 has a 16 bits address bus) is mapped to ram.

Most of the time we want at least on I/O port to be able to interact with our program:

*spec.ini*
```ini
[hardware.segment.ram]
kind=ram
start=0x0
size=0xfffe

[hardware.segment.tty]
kind=io
start=0xfffe
tty=true
```

The `tty = true` property will be recognized by toolchain implementation and will be mapped to a suitable user input/output channel.  

### A simple program

Lets write a simple program that output a constant string.

*hello.blah*
```assembly
# Define a global start symbol. This is not required but it is a practical hint for the linker
export start:

# Load the address of the symbol 'text', defined at the end of the file
movi r1 :text

# Load the addrss of the symbol '__io_tty'
# This symbol is automtically made available by the linker based on the specification file.
# In our case, its valeu will be the address of the 'tty' io port, AKA 0xfffe
movi r4 :__io_tty

loop:
	
	# Read a 16 bit word from 'text'
	lw r3 r1 0
	
	# if the word has the value 0, jump to 'end
	beq r3 r0 :end

	# Write the word we read to '__io_tty'
	sw r3 r4 0

	# Increment the pointer to text by 1
	addi r1 r1 1

	# Jump to the beginning of the loop
	beq r0 r0 :loop

# Define an 'end' symbol that poitn to an isntruction that stop the program
end: halt

# define a symbol 'text' and embbed a string data in the program
text: .ascii "Hello world !\n"
```

We can run our program: `cli asm --spec=spec.ini -build-dir=build --output=hello --also-run hello.blah`

Output:
```txt
Success: Successfully assembled hello.blah into 'build/hello.ro'
Success: Successfully merged 'build/hello.ro'
Success: Successfully linked 'hello'
Success: Running ... 'hello'
Hello world !
Success: Ran 'hello'
```


## Usage

### CLI

### Webapp

### Toolchain

- [RiSC16 Assembler](/wiki/assembler.md)
- [repositionable object](/wiki/object.md) file format
- [linker](/wiki/linker.md)
- [virutal-machine](/wiki/vm.md)
- compiler for [stacklang](/wiki/stacklang/index.md), a rudimentary imperative programming language
- [debugger](/wiki/debugger.md) curse tool for visualizing binaries and execution