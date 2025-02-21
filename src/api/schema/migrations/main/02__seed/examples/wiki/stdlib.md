# Standard Library

The stacklang language need a bit of assembly code to start (the 'runtime'), for setting up the stack and calling main for example. 

The standard library provides this functionality along with several userfull functions and can be easily bundled into a library file.  

## Linking the stdlib

With the CLI:  
`./bin/cli -l stdlib/*.blah stdlib/*.sl -o build/stdlib.lib`


## Functions

### left_bitshift

Perform [left logical shifting](https://en.wikipedia.org/wiki/Logical_shift)

Require: `<stdlib root>/left_bitshift`  
Prototype: `fun left_bitshift(word, by):_`

This function is automatically used by the compiler when using the operator `<<`

### right_bitshift

Perform [right logical shifting](https://en.wikipedia.org/wiki/Logical_shift)

Require: `<stdlib root>/root_bitshift`   
Prototype: `fun right_bitshift(word, by):_`

This function is automatically used by the compiler when using the operator `>>`

### multiply

Perform signed integer multiplication.  
Arithmetic overflow is undefined behavior.

Require: `<stdlib root>/prototypes`  
Prototype: `fun multipy(a, b):_`

This function is automatically used by the compiler when using the operator `*`

### putword

Output an hex representation of a given word to `__io_tty`.  

Require: `<stdlib root>/putword`  
Prototype: `fun putword(word)`

## Globals

### hex_digits

A null terminated array of word, each representin an ascii characters used in hexadecimal base: `"0123456789abcdef"`

Require: `<stdlib root>/prototypes`
Prototype: `var hex_digits: [16]`
