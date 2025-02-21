# Specification File

Specification file are configuration files that act both as
linker script and vm specification.

# [Default Specification](#default)

```ini
[linker.section.text]
start=0x0

[linker.section.stack]
start=0xff00
size=0x00ff

[hardware.segment.tty]
kind=io
start=0xffff
tty=true

[hardware.segment.ram]
kind=ram
start=0x0
size=0xfffe
```

It defines the memory space as:
- 65535 16 bits words, starting at address 0
- A single IO named `tty`, 16 bits sized, at addres 0xffff

It provides the following instructions to the linker:
- Put the section `text` at address 0 of the row binary
- Reserve the 0xff 16 bits words words from 0xff00 to 0xffff for section `stack`

Note that `text` is the default section name when assembling files.  
As per assembly language specification, the section can be changed any time:
```assembly
section text+0 export start:
nop # call main
section rodata 
export hexchar: .ascii "012356789abcdef" 
```
This is a common pattern for setting up the starting code at the very beginning of the text section.

Also note that a global symbol is autmatically defined by the linker for each section:
```assembly
movi r7 :__section_stack
``` 
This is another common pattern for initializing the stack pointer register (usually `r7`)

This specification can also be found:
- In the [example source files](/stdlib/default_spec.ini)
- In the webapp stdlib public project `builtins:stdlib:/default.ini`

### Hardware segments

All hardware segments have the following properties:
- kind (enumeration: `io | ram | rom`)
- start (`unsigned integer`)
- size (`unsigned integer`)

#### Ram

The ram segments have no other properties. It represent regular ram.

#### Rom

The rom segments have an additional property:
- source (`string` representing a file name)

Rom hardware segments will map the content of a file to the allocated address space.  
If the file is shorter, rom is zero initialized.  
If the file is larger, it is truncated in rom.  
Writes to rom are undefined behavior.  

#### IO

The io segments have additional properties:
- tty (`boolean`) mark the IO  as a TTY io. The size is set to 1 word.
- source (optionnal `string`) the name of a file to read from
- sink (optionnal `string`) the name of a file to write to

Reading or writing from an IO mapped region with another address than the start address of the IO is undefined behavior.
Both `source` and `sink` values support replacement by macros:

```ini
[hardware.segment.brainfuck]
kind=io
start=0xffff
source=$bf-source
```

The source of the brainfuck IO will be set to the value of the `bf-source` macro. 