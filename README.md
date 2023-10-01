# Blah

You know **con**langs, **Blah** is a **con**con (for con computer).  
It is a from-scratch computing environnment based on [RiSC16](https://user.eng.umd.edu/~blj/risc/).

**Blah** is a pet project that I am working on for fun. 
It serves no other purpose than entertaining me.  

It consists of:
- A [RiSC16 Assembler](/wiki/assembler.md)
- A [repositionable object](/wiki/object.md) file format
- A [linker](/wiki/linker.md)
- A [virutal-machine](/wiki/vm.md)
- A [compiler](/wiki/compiler.md) for a minimalistic higher-level programming language
- A [debugger](/wiki/debugger.md) curse tool for visualizing binaries and execution


All of which are bundled within a single CLI tool, written in [Crystal](https://crystal-lang.org/).

## TODO
- [x] Write an assembler able to ouput raw bitcode
  - [x] Data statements
  - [x] Basic math in offset
  - [x] Predefined symbols (stack, io)
  - [x] Relocatable object file and static linking
  - [ ] Better error output for linker
  - [x] Generate symbol for sections
  - [x] Allow to partition the address space between rom, ram and IOs
  - [ ] UTF-16 strings
- [x] Write a dummy virtual machine that can execute this raw bitcode
  - [x] IO
  - [x] Hello World
  - [ ] Propose memory paging mechanisms
  - [ ] Propose memory protection mechanisms
- [x] Design and write a compiler for a small stack language
  - [x] Write a program that do something (Brainfuck interpreter)
  - [x] Fix or don't fix undefined behavior due to cached var (add restricted keyword and disable all caching when not enabled)
  - [ ] Cache field of struct var when struct is restricted ?
  - [ ] Optimize for size
    - [ ] Better register usage 
    - [x] Use BEQ for local jump when possible
	- [ ] Improve linker to solve local BEQ early (they are relative)
	- [ ] Improve linker to strip unused symbol
  - [ ] Fix line/char hints
  - [x] Fix big move immediate overflow
  - [ ] Add error for stack size exceding small immediate size
  - [x] Minimal standard library
  - [ ] Fix or_equal comparison
  - [ ] Cast
  - [ ] In-file prototypes
  - [ ] Unsigned and signed arithmetic in stdlib
  - [x] Flag for trimming unused functions
- [ ] Write an OS
  - [ ] Relocate and load another program
  - [ ] Run multiple programs
  - [ ] Handle syscalls and barebone scheduler 
  - [ ] Memory management
- [ ] Define fixed spec for a computer
- [ ] Define a standard configuration/description mechanism for detecting hardware (kind of ACPI)

# Full example

Here is an example of what can be currently done with all this garbage:
Running 
```sh
./bin/cli -l stdlib/left_bitshift.sl stdlib/multiply.blah stdlib/putword.sl stdlib/right_bitshift.sl stdlib/stacklang_startup.blah -o build/stdlib.lib
./bin/cli -b build -s examples/brainfuck/brainfuck.ini -d bf-source=examples/brainfuck/hello.bf examples/brainfuck/brainfuck.sl build/stdlib.lib -o build/brainfuck
```

Will output
```
Hello World!
```

It compile and run a small program that will execute another program written in [Brainfuck](https://en.wikipedia.org./wiki/Brainfuck) 

Sources can be found [here](/examples/brainfuck/) or in this readme:

*examples/brainfuck/brainfuck.ini*
```
[linker.section.text]
start=0x0

[linker.section.stack]
start=0xff00
size=0x00fe

[hardware.segment.ram]
kind=ram
start=0x0
size=0xfffe

[hardware.segment.tty]
kind=io
start=0xfffe
tty=true

[hardware.segment.brainfuck]
kind=io
start=0xffff
source=$bf-source
```

*examples/brainfuck/hello.bf*:
```
++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.
```

*examples/brainfuck/brainfuck.sl*:
```
require "../stdlib/prototypes.sl"

fun load_io(io:*, destination:*, size):_ {
  var i = 0
  var buffer
  while ((buffer = *io) != 0xff00 ) {
    if (i == size)
      return 0
    *(destination + i) = buffer
    i += 1
  }
  return i
}

var program: [0x1000]
var ram: [0x1000]

fun main:_ {
  var pc = 0
  var ptr = 0
  var program_size = load_io(&__io_brainfuck, &program, 0x1000)
  var loop_count = 0

  if (program_size == 0x10)
     return 1

  while (1) {
    if (pc == program_size)
      return 0
    if (program[pc] == 0x3E)
      ptr += 1
    if (program[pc] == 0x3c)
      ptr -= 1
    if (program[pc] == 0x2B)
      ram[ptr] += 1
    if (program[pc] == 0x2D)
      ram[ptr] -= 1
    if (program[pc] == 0x2E)
      __io_tty = ram[ptr]
    if (program[pc] == 0x2C)
      ram[ptr] = __io_tty
    if (program[pc] == 0x5B) {
      if (ram[ptr] == 0) {
       	while (program[pc] != 0x5D || loop_count != 0) {
 	        pc += 1
	        if (pc == program_size)
      	    return 1
	        if (program[pc] == 0x5B)
	          loop_count += 1
	        if (program[pc] == 0x5D)
	          loop_count -= 1
        }
      }
    }
    if (program[pc] == 0x5D) {
      if (ram[ptr] != 0) {
        loop_count = 1
       	while (program[pc] != 0x5B || loop_count != 0) {
          if (pc == 0)
	          return 1
	        pc -= 1
	        if (program[pc] == 0x5D)
      	    loop_count += 1
	        if (program[pc] == 0x5B)
	          loop_count -= 1
	      }
      }
    }

    pc += 1
  }
  return 0
}
```

Other sources files used for building the stdlib can be found in the [stdlib directory](/stdlib)