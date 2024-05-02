# Internal

## ABI
Stacklang use a simple ABI, a convention on how we are going to handle various thing such as calling functions with parameters. Knowing the ABI allows interoperability (like defining or calling functions from/to another language, or from/to assembly).
The ABI is the following:
- Register r7 is the stack register. We use to store the address of the call stack
- Register r6 is used for storing the return address when performing calls
- Function symbols are: `__function_<function name>`
- Each function have this own section
- Gloval symbols are: `__global_<global name>`
- The stack is built this way:

For a function `fun foobar(param1, param2):_ { var a; }`

| Address | What is there |
|--|--|
|  `r7 + n` | `temporary vars` |
|  `r7 - 0x0` | `a` |
|  `r7 - 0x1` | `param 1` |
|  `r7 - 0x2` | `param 2` |
|  `r7 - 0x3` | `return address` |
|  `r7 - 0x4` | `return value` |
 
The top of the stack can grow unspecified to store temporary values. As you can see, both parameters and return value are stack based. To call a function:
- Ensure the r7 register contain an address suitable for growing the stack
- Put the parameter in the stack
- Jump to the symbol `__function_<function name>` with r6 containing the return address
- Read the return value if needed 
