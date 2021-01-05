# blah

Pet project where I intend to write a complete "usable" computer from as scratch as possible.
Currently I'm writing a compiler and vm for an assembly like language that I hope is simple enough for me to be able to write a processor for.

TODO:
- Write a LL parser builder
- Update compiler to use it instead of nasty regex
- Add sugar to he compiler: jump_eq & cie, data directive, address loading directive
- Make compiler output linkable object
- Add a simple linker
- Write the assembler
- Write the VM

## Grammer

Line = (Directive | Instruction)? + Comment?
Instruction = label? opcode (arg(, arg)?)?
Register = ...
Location = (:label)?(+-)?(Ox|Ob)?(num)

aditional opcodes:
jump_* to easy jump
goto to easy set ip

call and return are meta instrcution that creates stack frames. Need to reserve on of r* as stack pointer