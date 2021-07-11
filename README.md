# blah

Pet project where I intend to write a complete usable computer from as scratch as possible.
Based on the [RiSC16 ISA](https://user.eng.umd.edu/~blj/RiSC/RiSC-isa.pdf).
Written in crystal because it rules.

Quicktest:
```sh
crystal build src/cli.cr && ./cli examples/hello.blah examples/data.blah
```

Echo back example:  
```
movi r1 0xff00 # if we read this word from tty, it mean it's closed.
loop:
    lw r2 r0 :__io_tty_r # read w from tty in r2
    nand r3 r1 r2
    nand r3 r3 r3  # r3 = r1 & r2
    beq r1 r3 :end # roughly, branch if r2 & r1 == r1
    sw r2 r0 :__io_tty_r # write data r2 in tty
    beq r0 r0 :loop
end:
    halt
```

## Summary

There is a [command line](./src/cli.cr) that allows to perform various operation, see `cli help` for details.  
Overall, it can:
- [Assemble](./src/assembler/assembler.cr) a `.blah` flavored RiSC16 assembly file into a kind of [relocatable object](./src/assembler/object.cr).
- [Link](./src/assembler/linker.cr) one or multiple `.ro` file into a stactic binary.
- [Load and run](./vm/vm.cr) a static binary
- [Debug](./debugger/debugger.cr) a program with a curse UI allowing disassembly, stepping, breakpoints, memory and register display.
- [Compile](./src/stacklang/compiler/compiler.cr) a `.sl` stacklang file into an `.ro` file.

Specification files controls some characteristic of the VM and must be known at compile time (such as ram size, stack start address, io).  
Specification file are `.ini`  are handled by [spec](./src/spec.cr).  
It has sensible defaults when unspecified. You can specify the file with the `-s` option on the CLI.  
Spec file can also reference macro that should be provided with the `-d` option on the CLI.  

IO are emulated by the VM, and can be configured through spec files. By default, a single io `tty` at adresse 0xffff is defined and map to the STDIO.  

The linker will generate various symbol automatically:
- `stack` which contains the base stack address as per the spec.
- `__io_<name>_a` which containt the address of the associed io.
- `__io_<name>_r` which containt the offset to 0 of the address associed io. 
This is usefull because IO use end of address-space addresses by default, 
and this allows to read/write from an io in a single load/store instruction from 0 (through the always null register r0) with offset `__io_<name>_r`. 
Alternativewould require loading the address into a register before dereferencing it, 
which would almost always mean an additional two instructions (move immediate `__io_<name>_a`).  

Instruction can be sorted in various continuous blocks within a section. 
The linker will ensure everything fit, find the absolute address of each symbol and replace each reference to it with the real value.  

#### CLI default

If no command is given to the CLI, every non flag parameters will be considered as input and the compiler will try to assembler them, then link it and run it.  
Exemples:  
- Run a program that echo input: `cli examples/echo.blah` 
- Debug a program that display hello world: `cli -g examples/hello.blah examples/data.blah` 

## Assembly Syntax

## Stacklang

### Syntax oddities:

- `_` denote the word type. When an expression that ALWAYS require a type has no explicit type, it is a word by default.
  - `var foobar: _` is a word, `var foobar` too. `var foobar: *` is a pointer to a word.
  - But `fun foobar` is a function that does not return, while `fun foobar: _` is a function that return a word.
  - `struct Color { r; v; b }` is equivalent to `struct Color { r: _; v: _; b: _ }`.

### Require

Stacklang can `require` another `.sl` file relative to itself. This will not compile required file, but this allow to gather prototyping informations,
such as structure of types, prototype of functions and globals.  
As they are not compiled, the required files muse be compiled and linked along to avoid undefined reference at link time.
This also allows to require prototypes and actually link with another implementation (useful for interoperability between assembly and stacklang).

### ABI

Stacklang export symbols for each global and functions with this naming pattern:
- `__global_<name>` for global.
- `__function_<name>` for functions.
This allows to access a stacklang implemented global or function from assembly.
The oposite is also possible but the compiler must be made aware of the prototypes by requiring a file that will declare globals and functions type information. 
This prototype file must not be linked.
  
The ABI is defined this way:
- The R7 register is reserved for the stack address.
- When calling a function, the return address must be stored in R6.
- The parameters for a function must be written in the stack prior to calling
- The callee has the responsability of moving the stack and restoring it if necessary (it might be omitted if the callee does not perform any call).
- The stack frame is composed, from bottom to top:
  - Space reserved for return value if any. Size vary depending on type.
  - A reserved word (almost always used for storing the return address). 
  - Parameters, order size of each depending on function prototype.
  - Function internal values.
- So to call a function that does not return anything and accept a single word parameter, caller must write this parameter at address R7 - 2.
- Return value, when any, are left in place in the stack. The caller has the responsability of ignoring it or ensuring it saved/used befire it get overwrited
by future calls.
- So to fetch the return value of a call to a funtion that return a single word, the caller must read the address R7 - 1. 

## Roadmap
- [x] Write an assembler able to ouput raw bitcode
  - [x] Data statements
  - [x] Basic math in offset
  - [x] Predefined symbols (stack, io)
  - [x] Relocatable object file and static linking
- [x] Write a dummy virtual machine that can execute this raw bitcode
  - [x] IO (but meh)
  - [x] Hello World
- [ ] Design and write a compiler for a small stack language
  - [ ] Minimal standard library
- [ ] Write an OS
  - [ ] Load another program
  - [ ] Relocate and load another program
  - [ ] Handle syscalls and barebone scheduler 
  - [ ] Memory management
