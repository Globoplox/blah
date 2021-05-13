To be able to write code that can be loaded dynamically, the code must be able to 
be loaded at an arbitrary address (that may be known at runtime).
This mean that absolute jumps, rw and lw must be relative to the load address.

This mean there is a single value that we must never loose during the whole program... (a register, or a value that is repeated in each stack frame) 
In this solution the programmer must take it in account at all time
OR 
we can have a small piece of code at the beginnong of the relocatable code that will "relocate" itself.
This block of code would have the hardcoded location of all the place in the program and for each of them would add it's base address...
This mean the assembler must be able to recognize absolute call/lw/rw but this is not possible easely.
Maybe it could detect movi 'symbol'. The symbol being a local symbol (relative to zero), it never has any meaning if not relative to base address.
Relative jump (beq) are relative to expected pc, they don't need relocation: the symbol is absolute (relative to zero), then made relative to pc (which is absolute too)
Example: 
```
0x0 nop
0x1 nop
0x2 beq r0 r0 _my_sym
0x3
0x4
0x5 _my_sym: nop
```
Once symbol are solved:
```
0x0 nop
0x1 nop
0x2 beq r0 r0 ((_my_sym = 0x5) - (expected_pc = 0x2)) == 3
0x3
0x4
0x5 _my_sym: nop
```
So overall: assembler need a 'relocatable' switch that will keep track of all movi _symbol (that get resolved to two instructions...)
and then write the automodifying code. Issue is that the automodifying code will need to be able to perform bitshift ? Unless the loading code do it himself.
This way is cool because the same tricks can be used to perform dynamic linking of libraries


OR
the program could relocate himself by making all absolute relative to pc in advance.
This is NOT possible in RiSC16 because we can read PC only by performing an absolute call. (so we need pc to get pc without getting lost)
