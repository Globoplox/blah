# Blah
## What is it
### Purpose
**Blah** is a pet project that have been working on for fun on the course of a few years. It serve no other purpose than entertaining me.
Some people like building stuff, because they are nice, useful, new, smart or whatever. My kink is understanding how stuff work.  And I happen to like computers. I studied computer science and shit, it is cool, but it is very wide. I studied a lot of barebone C, some glimpses of internal stuff about OS, assembly. I work on embedded software (among other things) for a living. It gaves me some superficial knowledge of how computers works (in the sense of how I can play to videogames in 2020 because some smart people built a transistor 70 years ago), or actually more than knowledge, an educated guess of how everything works, layer upon layer.

Those *educated guess* I am talking about is what I am trying to challenge with this project. I already got the 'high level' of computer science mostly demystified by study and work, now I want to prove myself I'm not completely wrong about how I think the 'low level' stuff works and for this I'm mostly trying to rebuild it. Not from scratch because the point is understand and having fun, so I am still going to use modern tools.

So there is the point of this project: building a 'computer', or actually more something like a 'computing environment' that can handle some 'not completely trivial' tasks, but where I understand everything that is going on.
### What have been done so far
Currently, this project is a collection of tools written in [Crystal](https://crystal-lang.org/) (because that is the language I'm the most comfortable with these days), including:
- An Assembler, reading a file containing instruction and outputing binary following the specification of an **ISA**. More about said **ISA** soon.
- A Virtual Machine capable of running binary following the said **ISA**
- An Object file format for storing pre-assembled piece of codes
- A Linker to merge together the Objects into a fully assembled binary
- A kind-of Debugger for observing the state of the Virtual Machine
- A Compiler for a very unstable and barebone C inspired language
- A Command Line Interface for stitching everything together.

### Examples
Here is an example of what can be currently done with all this garbage:
Running 

    ./cli -s specs/bf.ini -dbf-source=examples/hello.bf stdlib.lib examples/brainfuck.sl
Will output

    Hello World!
That is actually a little more interesting than minimal hello world: It compile and run a small program that will execute another program written in [Brainfuck](https://en.wikipedia.org./wiki/Brainfuck) 

Lets get a look at everything happening here:
- The `./cli` is the command line interface crystal lang program that stitch everything together. You get it this way: `crystal build src/cli.cr`
- No operation has been given to the `cli`, by default it try to compile/assemble/link then run every file given as parameters.
- Argument `-s specs/bf.ini` is used to provide a configuration file that will set the behavior of the linker and the VM.

#### The specification file:

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
  - The `[linker.section.*]` parts allows to enforce the memory location and size of various piece of codes.
    - Here it is used to enforce that the instruction in the section `text` are going to be at the very beginning of the binary, so they are going th be the first instructions ran by the VM (assuming the binary is loaded in ram at address 0 and the instruction counter starts at 0, which is the behavior in our case). 
    - It is also used to say that there is a section named `stack` at the given address. This section will be used as the start address of the stack used by the compiled C like language. More on this much later.
  - The `[hardware.segment]` parts are used to configure the memory of the virtual machine. Put simply, it say that address from `0x0` to `0xfffd` included are regular ram, that the address `0xfffe` is an IO register that map to the outside world TTY so we can interact with the program a little, and finally the address `0xffff` is another IO register that will read from the file `$bf-source`. The `$` mean it is a macro for setting the actual file path from the CLI because it is more practical this way. 

#### Let's get back to the CLI
- `-dbf-source=examples/hello.bf` as you might have understood set the path of the file that the `0xffff` register map to.
- The file content here is 
```
++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.
```
- Which is a brainfuck program outputting hello world.
- `stdlib.lib` is not an option, it is an input parameter. A `.lib`file is a collection of object file, it is used because it is simpler that having to provide each dependencies of the program one by one. It represent the standard library of the 'high level' language and contains the startup file. Omitting this input file would result in a warning `Linking into a binary without 'start' symbol` and the program would run errand. 
- To obtain the the `stdlib.lib` file, run `/cli -l -o stdlib.lib stdlib/^prototypes.sl* ` (using zsh glob patterns. If you don't have them, just put every file in `stdlib/` BUT `prototypes.sl` as inputs).
- And finally `examples/brainfuck.sl`is the program we want to run.

#### The program itself
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
It is a very naively implemented brainfuck interpretor. If you can read C, you likely can read this file. Some hints about the most obvious differences (outside of the fact that it is very very very minimalist and unstable):
- Type are expressed this way `<var>: <Type>`
- the symbol `_` is the word type  (you can thing of it as C `int`) and is the default type when an expected type is omitted
- So `*_` is a pointer on word (and `*` is too)
- Functions without parameters do not need the parenthesis `fun main:_`
- There are no preprocessor nor header file, `require` will fetch the given file and extract the prototypes of the symbol it defines (but the file won't be compiled itself).
- the `stdlib/prototypes.sl` file is not meant for being compiled, it is kind of a header file (yeah I know I said there were none sorry) for specifying the existence and prototypes of a few symbols that are defined outside of the language realm (defined in assembly in our case)
- The symbols `__io_brainfuck` and `__io_tty` are defined automatically be the language, they act as `_` typed globals variable whose address is the start address of the corresponding hardware segment. So the expression `__io_tty = 0x40` will write the value `0x40` at the memory location  `0xfffe` (which the VM has been instructed to map  to the TTY, so the program would output the character `'@'` in the terminal.
- The value of the IO registers that map to closed source will be `0xff00`, this is how the `load_io` knows it reached the end of the `hello.bf` file.

## Fondamentals
When I started this project, I knew I needed and **ISA**, or lets say a **CPU** architecture both simple enough that the assembler and VM wouldn't be annoying to write, but also practical to use. And I also wanted something simple enough that I could imagine writing the gate level logic circuit of the CPU by myself. I searched a little and stumbled upon [RiSC16](https://user.eng.umd.edu/~blj/risc/), an educational ISA written by the Prof. Bruce Jacob at the University of Maryland. [This document](https://user.eng.umd.edu/~blj/RiSC/RiSC-isa.pdf)  was everything I wished for so I rolled with it.
So it is a fully 16 bits ISA: 16 bits addresses, 16 bits words, 16 bits instruction. 8 register (including an always-0 register), 8 instructions.

### Some words
I really like this pet project. But sadly I can hardly share it with any friend of mine, because even the one that are computer scientist never really cared for those specific bits of computer science, and so while they can share the own hobbies, I'm usually stuck when trying to explain what the hell I am doing. And actually almost none of my friends actually get what an **ISA** is. Me neither actually, I don't know the real definitions if there is one, but I feel like I can tell that something is an ISA and something is not. Same go for all those fancy words that can mean so many things: **API**, **ABI** and so. 
But I happen to love vulgarisation, so this is an opportunity yo have some fun. Obviously I am a total dumbell in those fields, I am juste trying to have fun and everything I tell is likely a misconception, but I will still try to explain what I mean and what I understand when I read **ISA**, in a way that I hope people I could want to show this doc would understand.

#### Hysterical babbling
Let's say a computer is something that has  some inputs and some outputs, and that perform a task. For example, let have a computation system fit for doing addition between small numbers: measuring cups. You have to cups with measuring marks. One has 2cl of liquid. Another has 7cl of liquid. Pour one into another, read the marks: 9cl, congratulation, you have a computational system that can perform simple addition !
Well everything I explained here, could be an **ISA**. It is a computer with no addressable memory, two registers whose size is expressed in volume instead of an amount of bits, and single instruction (which is: set register 1 to zero and register 2 to the sum of register 1 and register 2, overflow result in register 2 to be set at max capacity and undefined slip hazard). Now this example is very simple because there is only one instruction , so there are no instruction decoding. Let get another metaphor with two instructions and so some kind of decoding.

But not now I need to take a shower and IDK go out of my cave or something 

Ok I'm back I took a nice bath and had coffee with some pastries honhonhon I love being french

SO HAVE I TOLD YOU ABOUT [NANDGAME](https://nandgame.com/) ? It is a small 'puzzle' game that will make you build a computer from a bunch of nand logic gate. It's not very complicated and once you get through the boring combinatorial logic (is that a word ? Does it mean what I think it does ? I don't care enough to check) it beacme pretty easy. The part I like the most is the one about the instruction decoding. Because once you got that, you stop seeing assembly as a bunch of word that people tell you is 'raw computer language' and it make no sense because it is like word and letters and number and everyone told you 'computer understand only 0 and 1 y'know'. Once you get how the binary representation of the assembly actually is mostly a bunch of switch that all 'mechanically' (well electrically but who care) open and close some pipes, you begin to get a sense of how this all works. But I can't think of a good way to make someone understand this (out of their goodwill) other than having them does the Nandgame so I won't try much more and I will focus on explaining a little more what an ISA mean here.

So let's decide we have a computer:
It has memory, which is a bunch of indexed box. Each box contains a bunch of small on/off switch.
It has registers, which are a bunch, a few actually, reusable stick notes.
It has a processor, which is someone who, every few seconds, will open the box in front of him and read the switch.  He interpret the switch following a strict protocol: for example, maybe the first switch is ON if he need to read memory box whose number is written on a sticky note, OFF if he need to read the sticky note itself. The second may be ON if he need to do an incrementation, and the third would act the same way as the first but with the output instead of the input. Ok I didn't really tried to make it an interesting computer, but it is simple enough and can already do stuff such as thoses (in babbling pseudocode, considering input and output are number represented by other switch in the box):
```
stickies[output] = stickies[input] + 1
stickies[output] = stickies[input]
memory[stickies[output]] = stickies[input] + 1
memory[stickies[output]] = stickies[input]
stickies[output] = memory[stickies[input]] + 1
stickies[output] = memory[stickies[input]]
memory[stickies[output]] = memory[stickies[input]] + 1
memory[stickies[output]] = memory[stickies[input]]
```
What I'm trying to tell is that with only three switches, we can already do a lot of kind of different things, with each switch enabling one feature independent of others. Now imagine the same but with more switch (or with more interesting features for each switch/switches combination).
So the protocol followed by the person to interpret the switches is an ISA. In a processor it is engraved in the chip by logic circuit.
An ISA is the list of thing the processor can do and how to move the switch so it does what you want it to do. Now the switch are just a bunch of ON/OFF stuff, so why not representing them as zeroes and ones ? Like, `101` ? And let's say we have four sticky notes, named `00, 01, 10 and 11`. Now let say we order the switches this way: operation, input, output. This way we have `0100011` would mean `stickies[3] = stickies[0] + 1`. We can got even further and give a little name to each eight operation, (in our case it wouldn' make a lot of sense but USE YOUR IMAGINATION) like, `010` could be named `INC` for `increment` so it is easier to write. Booooom you just reinvented assembly langage !

Ok I feel like I wrote a lot of unclear and not very bright stuff but it's hard y'know ? If you feel frustrated then GREAT ! Go do the Nandgame you will understand everyyyyything.  

So thats it. Our ISA has 8 stick notes, the first now is always 0. It can do 8 different operations and each box contain 16 switch.

### RiSC16
#### Specs summary
In case you have not read the document, here is a quick summary:
- 8 16 bits registers (r0 to r7), register r0 always has value 0 (write to it are discarded).
- Up to full 16 bits address space
- No I/O related instructions, so if the computer has I/O, they must be [Memory Mapped IO](https://en.wikipedia.org/wiki/Memory-mapped_I/O)
- 8 different operations (as 16 bits instructions)
	- Add: `ra = rb + rc`
	- Addi (add immediate): `ra = rb + 7 bits signed immediate`
	- Nand ([not and](https://en.wikipedia.org/wiki/NAND_gate)): `ra = ~(rb & rc)`
	- Lui (load upper immediate): `ra = (10 bits immediate) << 6`
	- Sw (store word): `memory[rb + 7 bits signed immediate] = ra`
		- Also used for I/O write
	- Lw (load word): `ra = memory[rb + 7 bits signed immediate]`
		- Also used for I/O read
	- Beq (branch if equal): `pc += 1 + (7 bits signed immediate) if ra == rb`
	- Jalr (jump and link): `ra = pc + 1; pc = rb`
		- In Beq and Jalr, `pc` is the `program counter`, aka the internal register holding the address of the current instruction 
- 16 bits words, of the potential 2¹⁶ addresses can address a distinct word (the actual mapping of the memory is up to the computer implementation).

- The assembler language specs (we are not really talking about the ISA anymore) allows for a few additional macro instruction and statements (syntax sugar added to the assembly language because they are helpful):
	- Nop (no operation), resolve to `add r0 r0 r0`, it does nothing and the instruction read as zéro if interpreted as a number
	- Halt, resolve to `jalr r0 r0 1` (the last parameter is a 7 bits immediate, anything but zero is illegal. Could be used for system calls later but currently it is illegal.
	- Lli (load lower immediate): resolve to `addi ra ra (7 bits signed immediate) & 0b111_111`
	- Movi (move immediate), resolve to `lui` then `lli`to load an immediate in a register in two instructions.
	- `.word` to embedded a raw word
	- `.ascii` to embedded a raw ascii string. Each char take a full 16 bits word.

####  What is an immediate ?
An immediate is a value that is written in the assembly and that get encoded in the instructions. Some instructions have a dedicated area for some bits that can contain raw values.
#### What does it means, 7 bits or 10 bits or whatever immediate ? 
Number in binary are expressed this way: (`0b`indicate base 2 aka binary, `0x` base 16 aka hexadecimal).
- `1` in decimal is `0b1` in binary
- `7` in decimal (aka 2⁰ + 2¹ + 2²) is `0b111` in binary
- `5` in decimal (aka 2⁰ + 0 + 2²) is `0b101` in binary

As you notice it take three symbols to express the value 5 or seven in binary.
A *n* bits immediate mean you can store a number that need up to *n* symbols to express in binary. So with enough bits real estate to store a 7 bits immediate, you can store a value from 0 (`0b0000000)`, up to 2⁰ + 2¹ + 2² + 2³ + 2⁴ + 2⁵ + 2⁶, aka `0b1111111`, aka 127.
#### What does it means singed or unsigned or unspecified immediate ?
Immediate are binary data. In the assembly language we express them as numbers, but it can be used to store arbitrary information. When we do operation at the bit level, such as [`nand`](https://en.wikipedia.org/wiki/NAND_gate), `lui` or `lli`, we do not care about the meaning of the bits. So there is no notion of sign.  

But with `add, addi, beq, lw, sw`, we are interpreting the given immediate (and values within registers) as numbers. And beside their values, numbers can sometimes have a sign, + or -. We need to support kind of negative numbers. But that seem annoying. Addition and substraction are not the same and substractions looks more annoying. Hopefully, there is a way around it. The [complement by 2](https://en.wikipedia.org/wiki/Two%27s_complement) form allows to easely perform substraction from an addition by formatting our negative numbers in a smart way, that work for signed or unsigned numbers. It just works because of math.  With the  complement by two form, split the 'number space' in two: with our previous example of 7 bits immediate (0 to 127), we say that value from `0b0000000` to `0b0111111` (aka 0 to 63) act as normal, but then, `0b1000000` to `0b1111111` are for negativ numbers and they go from less to more: (-64 to -1). Aka, `-n == 64 - n`. In binary it means the MSB (most significant bit, aka leftmost bit) is 0 for positiv number, 1 for negativ. And because of math, is we ignore overflows (when we try to put a value that need more bits to store than available), we can actully perform addition bewteen positiv and negativ and it will yield a correct results. 
In binary, to get the complement by two of a number (aka itself but switching the sign), you perform the binary not operation then add 1: 
- 5 is `0b0101` (we have four bit number)
- -5 is `!(0b0101) + 1` aka `0b1010 + 1` aka `0b1011`

#### The assembler language
The assembler language is a very simple programming language which allow to describe a program (or not a program infact) by specifying each instruction one after another:
```
lw r2 r0 3
lw r3 r0 4
add r1 r2 r3
```
The assembler *program* (that transform the assembler *language* into binary language that can be decoded as is by the processor, following the ISA, will output the following:
```
# Opcode | reg A | Reg B | 7 bits signed Immediate
0b101    | 010   | 000   | 0000011
0b101    | 011   | 000   | 0000100
# Opcode | Reg A | Reg B | 4 bits padding | Reg C
0b000    | 001   | 010   | 0000           | 011 
```
In hexadecimal, that is a 3 words / 6 bytes blob:
`0xA803 0xAC04 0x0503` 
We can test it easily:

    echo "lw r2 r0 3\nlw r3 r0 4\nadd r1 r2 r3" > examples/minimal.blah
    ./cli asm -u --silence-no-start examples/minimal.blah -o minimal
    hexdump -C minimal
Displays:

    00000000  a8 03 ac 04 05 03                                 |......|
    00000006

Yay !
Now we get how we go from assembler language text to a binary blob that we can feed a processor following our ISA.  

But we want a little more from our assembler, because programming is hard works:
##### Macro instruction and statements
We said earlier that we had some 'not ISA' macro instructions, that are just shortcuts for other instructions, and data statements to put raw data in the final binary:
```
movi r1 -78
.word 0xAAAA
.ascii "hello"
```
Assembling and hexdumping, we get: 
```
00000000  67 fe 24 b2 aa aa 00 68  00 65 00 6c 00 6c 00 6f  |g.$....h.e.l.l.o|
00000010
```

##### Labels
Labels are not variables. Label are not even constants. Labels are macros that you can define and whose values will be the offset of the line where they are defined:
```
.ascii "XXXXXXX"           # This take 5 words in the binary
this_is_a_label:         # It will have the value 5.
movi r1 :this_is_a_label
addi r1 r1 0x30          # 0x30 is the ascii value of character 0
movi r2 :__io_tty        # talking about this __io_tty label later. 
sw r1 r2 0  # write the value of :this_is_a_label + 0x30 to an memory mapped io register linked by default to the tty running the virtual machine so we can look at the result
halt
```
The command 
             
    ./cli --silence-no-start examples/minimal.blah
Will output:

    7

#### Examples

```
start:
movi r1 :text
movi r4 :__io_tty
loop:
        lw r3 r1 0
        beq r3 r0 :end
        sw r3 r4 0
        addi r1 r1 1
        beq r0 r0 :loop
end: halt
text: .ascii "Hello world !"
```
```
 ./cli --silence-no-start examples/minimal_hello.blah
 ```
```
 Hello world !
```
### The Virutal Machine
I don't have a computer running the RiSC16 ISA at hand right now. Which is kinda  logical since the whole point of this project is to build one, bruh. But I need to test my stuff, so I need an emulator. Hopefully the ISA is very simple, so writting a program that read the binary blob and execute it is very easy with current modern computing resources.
The VM is very simple: you get an instruction, you decode it, you execute it, repeat. Even in C it wouldn't be much code. The VM does one thing a little more complicated tho. It does not only emulate the processor and memory, but try to also handle some kinds of I/O. That is where the `[hardware.segments]` from specification files are important. They describe which part of the memory space are dedicated to what. Aka, what happens where running `sw` and `lw` on a given memory location. It offer various behavior, including an I/O register mapping to a tty, reading/writing from files, ram and rom. That allows our virtual computer to interact with us a little.
You should be able to most of what is possible with the examples you have already seen.

### The assembler program
I told that the assembler were building a binary blob from the assembler language text. This is half true. It output a intermediary format, that is then linked by another 'program', the *linker* into the final binary. This extra step take care of various thing that make a lot of what was said before comfortable lies. But this is for later. Just keep this intermediary step in mind.

### The CLI
The Command Line Interface is a messy piece of code that read command line parameters and do stuff according to them. It grew into a mess because I'm lazy and that's not the fun part. It's unlikely I keep this up to date so you can just run `./cli help`.
Small hint: if there are no command given, it default to `asm -ur` (also run, and do not serialize the intermediary files I spoke about in the paragraph just above.
### The "debugger"
I'm bad at not making mistake. But I'm also too lazy to write stuff that detect mistakes. So I crafted a kind of environment that show what is happening inside a VM so I can look at my mistakes live. 
To  run in the debugger, add `-g` to the CLI. It allows to watch the registers and memory states, execute step by step and set breakpoints. It's also kind bugged, don't watch the stack parts too much please it is kinda shameful. 
Oh I forgot it's curse based. So it run in a tty. I would put a picture but I don't know where to store it so /shrug. 
## Into the rabbit hole
A little more fun:

Having multiple sources files:
- Sections (to position code following given constraints)
- Exported symbols
- Object file (for precompiling, sections)
- Section in spec files
- Linker
  - How the relocation works

More Bonus:

- Lib files
- CLI


Stacklang:
- A simple language
- A simple compiler
  - The ABI
- The STDLIB

Still more bonus:
- DCE





