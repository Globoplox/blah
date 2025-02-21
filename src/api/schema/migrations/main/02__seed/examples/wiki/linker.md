# Linker

The linker is a tool that operate on [object files](object.md).  

It has two capabilities:
- Mergeing several object files into a single [merged object file](object.md#Merged)
- Linking a sibgle merged object file into a raw binary blob with all references solved 

When attempting to link an object file that is not mrged, the linker will try to merge this single object file to fix all section fragment relative position and detect any conflict.

## [Dead Code Elimination](#dce)

 Dead Code Elimination is a feature of the linker that is enabled by default. Its purpose is to remove from a compiled binary the sections that are unused in the final binary. It works only for sections that are marked as `weak`.  

 Note that by default all [stacklang](stacklang.md) functions are hosted in their own  `weak` section.