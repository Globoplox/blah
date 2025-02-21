# Object File

Object files are container for unliked binary code and raw data.  

An object file is a collection of fragments of code and data that all belongs to a section.  
Those fragments can optionally be given an offset with a section.
Fragments can also hold definitions of symbol and references to them. 
This allows the fragments to be position independent and references each other. 

Obejct files are the produce of the following operation:
- Assembling an assembly file
- Compiling a file
- Mergeing several object files with the linker will output a single object file

### Merged

A collection of object files can be merged. A merged object file has all its fragments and sections position relative to each other permanently fixed. 

## Linking

An object file can be [linked](linker.md) into a raw binary file. Linking will solve all references and replace them with the definitions accordingly to several internal rules.

## Libraries

Library files are simple containers holding several object files. They are helpful in situation where a lot of object files are commonly used together. Note that the [linker perform DCE](linker.md#DCE) to trim unused sections from the final raw binaries, so linking with a library files containing potentially unused symbols or function is not harmful.