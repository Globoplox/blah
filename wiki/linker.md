# Linker

## [Dead Code Elimination](#dce)

 Dead Code Elimination is a feature of the linker that is enabled by default. Its purpose is to remove from a compiled binary the sections that are unused in the final binary. It works only for sections that are marked as `weak`.