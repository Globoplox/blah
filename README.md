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
        .ascii "garbage"
		nop
		.ascii "other garbage"
```

## Components

### Top-Level
[RiSC16](./src/risc16.cr) contains the definition of the ISA.
It holds the base *Instruction* class encoding and decoding methods.

### Spec
[Spec](./src/spec.cr) is a class holding configuration for the toolchain, 
such as memory mapping and io informations. It can be parsed from .ini files as seen in the [specs directory](./specs).

### Assembler
The [assembler](./src/assembler/assembler.cr) module holds various class and methods used to assemble a bunch of assembly file into bitcode.
It works by creating a unit, parsing the input file, indexing the unit then solving it.

#### Statement
A statement is anything that can be assembled. It must be able to declare its expected bitcode size and write it's bitcode representation.

#### Unit
An [unit](./src/assembler/unit.cr) represent a program or a part of one.
It regroup line of codes that can freely share symbols definitions.
It can parse a file in LOC, then perform indexing of symbol, solving statements that require context data, and write the bitcode.

#### Loc
A [line of code](./src/assembler/loc.cr) represent a single line of code. 
It can holds comments, labels definition, a statement and context information (line number and source).

### Complex
A [complex](./src/assembler/complex.cr) represent a word expressed as a literal (in decimal, hex, or binary), 
absolute or relative to a label.
It require solving.

#### Instruction
An [instruction](./src/assembler/instruction.cr) is a statement that represent a single instruction.
It require solving for handling potential complexes.

#### Pseudo Instruction
An [pseudo instruction](./src/assembler/pseudo/pseudo.cr) is a statement that represent a macro instruction that will resolve to multiple instructions.
Additionaly to standrd RiSC16 pseudo-instruction, there are:
- `call <immediate> <stack register> <...saved registers> <return value register>`: save registers on stack and call immediate. 
On return, unstack register and put return value in the return value register.
- `function <stack register> <return address register>` sugar for putting the return address register on stack. 
It expect a reserved space in stack for storing the return address. 
It works well with `call` that will store the return address in the return value register and will reserve space in stack for the writing of the adress.
- `return <stack_register> <return value register> <temporary register>` will swap the return address and return value in stack then jump to the return address.

#### Data
A [data staement](./src/assembler/data/data.cr) is a statement that represent raw data. They begin with a '.'.
- `.word` store a word. It can be expressed as a complex.
- `.ascii` store a ascii stringone char per word. Does not add a null char.

### VM
The [VM](./src/vm.cr) can be created from a spec, load a bitcode-encoded program, and execute it.
It maps IO registers to configurable memory range. Specs can specify the path of a device to map for input and output of an io register. 

### Debugger
The [debugger](./src/debugger.cr) is a very WIPy tool for visualizing the execution of a program. 

### CLI
All tools can be used from a [CLI](./src/cli.cr). Just run it with 'help' to get an idea of how it works.

## Roadmap
- [x] Write an assembler able to ouput raw bitcode
  - [x] Data statements
  - [x] Basic math in offset (absolute difference between offset for data sizes)
  - [x] Predefined symbols (stack, io)
  - [ ] Defines can be used for label ? (no?).  default value for defines ? (no?). Raise on missing ? (yes!)
  - [ ] Static linking: Multiple source, micro runtime, linker script ?
    - Linker script could be as simple as defining sections in specs files
	- Sections would have name, start, size. Size could be replaced by a min/max size, start could be replaced by a 'after' another section
	- Sections could have 'negative size' to make them grow decreasingly
	- Sections start and sizes would create predifined symbols (and we would remove stack from general spec info, to define it as a section ?)
	- A meta statement (first of it's kind) would allow to specify the section (and potentially an offset) to write following instruction in
	- Compiler would then perform check within sections and between sections to ensure everything fit
	- Compiler could output a new kind of binary to allow loading sections far in memory without creating fat binary
	  - Could be as simple as: (u16 address of section)(u16 word size of section)(section bitcode) repeated for each section.
	- Since we already added a special statement for placing bitcode in section, let's add a modifier for symbols to allow reference from other units
	- Then we could have something along the line of: 
	  ```
	  # Hypothetical synatx
	  # In section ram, enforcing offset 0 (not specifying it would mean 'after what could have been put in section'RAM') 
	  section RAM+0x0: 
	  movi r7 :__section_stack_start
	  call :main r7, r6
	  halt
	  ```
      as startup code.
	  And in another unit, somewhere: 
	  ```
	  extern main: function r7 r6
	  ```
- [x] Write a dummy virtual machine that can execute this raw bitcode
  - [x] IO (kinda)
  - [x] Hello World
  - [ ] Write a program that do something (brainfuk vm in progress)
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
