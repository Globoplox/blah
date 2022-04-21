# Loading programs
# syscall
# allcoating memory

# Os need control of the whole memory, so it must know where it is located.
# Stacklang compiler currently pack everyhing but give no garantee of size.
# OS need his own stack
# OS need to be bootstraped in assembly
# OS need a way to know it's own size/location so everything else is supposed to be free or known IO
# I need the spec of the vm to be set before writing an os

# => Specfile/linker need a way to share the end of a section
# => Specfile/linker should try to pack similar section together ? __function ...
# => Specfile/linker should be able to specify order of sections ?

# => Thats why I need a mbr: minimal program, sitting at 0, able to load and start an OS (static linked) (load location is by convention)
MBR give size info to the OS before calling it.

# Need a 'load at' linker parameter to compile OS
