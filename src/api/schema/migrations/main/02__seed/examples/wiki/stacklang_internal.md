# Internal

## ABI
Stacklang use a simple ABI, a convention on how we are going to handle various thing such as calling functions with parameters. Knowing the ABI allows interoperability (like defining or calling functions from/to another language, or from/to assembly).  
The ABI specification are the following:
- Register r7 is the stack register. We use to store the address of the call stack
- Register r6 is used for storing the return address when performing calls
- Function symbols are: `__function_<function name>`
- Each function have this own weak section
- Global symbols are: `__global_<global name>`
- The stack is built this way:

For a function `fun foobar(param1, param2):_ { var a; }`

| Address | What is there |
|--|--|
|  `r7` | `return value` |
|  `r7 + 1` | `param 1` |
|  `r7 + 2` | `param 2` |
|  `r7 + 3` | `usually the return address, but left to function discretion` |
|  `r7 + n` | `temporary values` |
 
The stack can grow unspecified to store temporary values.  
Both parameters and return value are stack based. To call a function:
- Ensure the r7 register contain an address suitable for growing the stack
- Put the parameter in the stack
- Jump to the symbol `__function_<function name>` with r6 containing the return address
- Read the return value if any / needed
