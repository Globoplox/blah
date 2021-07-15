// Declare variables and functions that are implemented in assembly.
// It must not be compiled, as it would conflict with the actual implementation.

// This notify compiler there is a global error_code_success of type available.
// This will generate an object with a reference on a symbol __global_error_code_success, representing the address of the global
var error_code_success
var error_code_success_ptr:*

// Yummy yummy null ptr, useful to test ptr stuff
var null_ptr:*

struct Color { r;g;b }
var color_green : Color
var color_green_ptr : *Color