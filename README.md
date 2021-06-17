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

### Syntax

#### Instruction
An instruction is a statement that represent a single instruction.

#### Pseudo Instruction
An pseudo instruction is a statement that represent a macro instruction that will resolve to multiple instructions.
Additionaly to standrd RiSC16 pseudo-instruction, there are:
- `call <immediate> <stack register> <...saved registers> <return value register>`: save registers on stack and call immediate. 
On return, unstack register and put return value in the return value register.
- `function <stack register> <return address register>` sugar for putting the return address register on stack. 
It expect a reserved space in stack for storing the return address. 
It works well with `call` that will store the return address in the return value register and will reserve space in stack for the writing of the adress.
- `return <stack_register> <return value register> <temporary register>` will swap the return address and return value in stack then jump to the return address.

#### Data
A data statement  is a statement that represent raw data. They begin with a '.'.
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
  - [x] Basic math in offset
  - [x] Predefined symbols (stack, io)
  - [x] Relocatable object file and static linking
- [x] Write a dummy virtual machine that can execute this raw bitcode
  - [x] IO (but meh)
  - [x] Hello World
  - [ ] Write a program that do something
- [ ] Design and write a compiler for a small stack language
  - [ ] Minimal standard library
- [ ] Write an OS
  - [ ] Load another program
  - [ ] Relocate and load another program
  - [ ] Handle syscalls and barebone scheduler 
  - [ ] Memory management
