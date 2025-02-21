# Assembler

The assembler tool read assembly files and produce [object files](object.md).  

## Usage

The assembler can be invoked with the [CLI subcommand asm](cli.md).

Example: 
```sh
cat <<BLAH > test.blah
export start:
movi r1 :__io_tty
movi r2 :text
movi r3 :text_end
loop:
    lw r4 r2 0
    sw r4 r1 0
    addi r2 r2 1
    beq r2 r3 :halt
    beq r0 r0 :loop
halt: halt
text: .ascii "Hi\n"
text_end:
BLAH

# Build the CLI if not yet done
shards build
# Assemble the file into a raw binary (with default specs specs binding std in/out to address :__io_tty)
# It first invoke the assembler to produce an object file (-u prevent it to be serialized)
# Then invoke the linker to produce a raw binary file
./bin/cli asm test.blah -o test.bin -u
# If you wish to look at the object file:
./bin/cli asm test.blah -o test.bin
hexdump --canonical test.ro
# Dump the content for inspection
hexdump test.bin
# Run the resulting binary file in a VM with same specs
./bin/cli run test.bin
# Same with debug (press c to run, q to quit)
./bin/cli run test.bin -g

# Alternatively, the CLI default behavior will also handle it simply with:
./bin/cli test.blah 
```

## Syntax

The assembler is based on the specification of the [RiSC16 assembler](https://user.eng.umd.edu/~blj/risc/RiSC-isa.pdf) with a few addition.

### RiSC16 ISA sepcification

It is a fully 16 bits ISA: 16 bits addresses, 16 bits words, 16 bits instructions. 
It has 8 word register (1 always-0 register and 7 general purposes register), and 8 instructions.

In details:
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
		- In Beq and Jalr, `pc` is the `program counter`, aka the internal register holding the address of the current instruction.
- 16 bits words
- A potential of 2¹⁶ addresses can address a distinct word (the actual mapping of the memory is up to the computer implementation).

The assembler language specification allows for a few additional macro instruction and statements:
- Nop (no operation), resolve to `add r0 r0 r0`, it does nothing and the instruction read as zéro if interpreted as a number
- Halt, resolve to `jalr r0 r0 1` (the last parameter is a 7 bits immediate, anything but zero is illegal. 
- Lli (load lower immediate): resolve to `addi ra ra (7 bits signed immediate) & 0b111_111`
- Movi (move immediate), resolve to `lui` then `lli`to load a full word immediate in a register in two instructions.

Immediates are value that are written in the assembly and that get encoded in the instructions. Some instructions have a dedicated area for some bits that can contain raw values. 

Given the following input:

```
lw r2 r0 3
lw r3 r0 4
add r1 r2 r3
```

The assembler will output the following:

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

```sh
    echo "lw r2 r0 3\nlw r3 r0 4\nadd r1 r2 r3" > test.blah
    ./bin/cli asm -u test.blah -o test.bin
    hexdump -C test.bin
```

Will display:

```
    00000000  a8 03 ac 04 05 03                                 |......|
    00000006
```

### Blah Addition

The syntax is similar to the one proposed on the specification, with few deletion and addition:
- Labels are allowed to exists by themselves outside of an instruction
- Labels reference must starts with `:`
- The `.fill` and `.space` directives are not supported
- Directive `.word` is added, which behave similarly to specification's `.fill`
- Directive `.ascii` is added which store a raw word per character in the string
- A section specifier can be added before label declaration
- Label can be marked for export


#### Added statements

Given the following input:

```
movi r1 -78
.word 0xAAAA
.ascii "hello"
```

The assembler will output the following:

```
00000000  67 fe 24 b2 aa aa 00 68  00 65 00 6c 00 6c 00 6f  |g.$....h.e.l.l.o|
00000010
```

#### Section specifier

The section specifier can be used anywhere, it comes first before the label declaration and statement.
It take the form `section <optional_weak_tag> section_name<optional_offset>`.

The section specifier are stored in [object files](object.md) and used by the [linker](linker.md) to position sections. The default section is `text`.

The weak tag can be used to mark this piece of code as not usefull by itself, this mean that when [Dead Code Elimination](linker.md#dce) is run, weak section that are not directly or indirectly referenced by non weak sections will be removed. 

The optional offset can be used to position instruction/data relative to the start of the section. Conflict will be detected by the linker.

```blah
section text+0x0
movi r7 0xffff
movi r6 :__function_main
jalr r6 r6 0x0
```

In this example, we ensure the text section start with a stack initialization then call main.
If the linker script is configured to write the text section at the expected entry point of the program, then it ensures that these are the very first instruction that will be run. 

#### Label export

Label can be marked for export by prepending them with the export keyword: `export main:`.
This is used by the linker to allow the usage of this label as a global symbol that can be referenced by others sections. Non-exported labels stay local to their section.