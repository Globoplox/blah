/*
  Tested:
  - additions (a + b + 6 + 7 + 7)
  - binary not (~0x0FF0, ~a)
  - reference of simple local or gloal identifier (&a, &glob)
  - dereference (*&b)
  - dereferenced assignement (*a = b)

  To check: 
  - unloading globals
  - struct field access and lvalues (and cache coherence)
*/

var glob

/* 
  Works well and is pretty smart about reusing literal values and rotating registers 
  In this example, a is given a stack address (0x2 (0x0 is for the return value, 0x1 for the return address)) because it is referenced (&a)
  but b is never given a stack address because the program is simple enough it can stay in a register
  The a stack addres (0x2) is read when loading a for the return value
  Note that since we never directly write to a before reading it (we do it but through an alias) the compiler should probably 
  issue a warning.

  Note that if we initialize a (lets say with 0 as it is the easiest), then the code will grow by one instruction but not for the allocation of the 0 to a
  on the first line (a stay hosted in register r0), but because taking the address of a (&a) cause a to be restricted and immediately spilled to the stack
  (so when doing &a, it immediatly "sw r0 r7 Ox2"). This avoid conflict such as "return a" returning 0 because a would still be hosted in r0, despite it's 
  allocated memory location value having changed
*/
fun main:_ {
  var a
  var b:* = &a
  *b = 0x0FF0
  return a
}
