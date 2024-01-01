# Stacklang

Stacklang is a work-in-progress, minimalistic C-inspired languages.  

```
require "things_doer"

fun main {
    return do_the_thing()
}
```

It is composed of:
- A compiler parsing stacklang files (.sl) and producing [object files](/wiki/object.md)
- A minimalistic standatd library

While it much more practical to use than assembly, it generally inefficient code.  
It is not feature complete, can be buggy, has specification hole and pretty much a constant WIP.
But outside of heavy refactoring time it does work.  

## Specification 
See [Specifications](/wiki/stacklang/specification).

## Internal
See [Specifications](/wiki/stacklang/internal).
