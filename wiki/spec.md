# Specification File

Specification file are configuration files that act both as
linker script and vm specification.

# [Default Specification](#default)

```ini
[linker.section.text]
start=0x0

[linker.section.stack]
start=0xff00
size=0x00ff

[hardware.segment.tty]
kind=io
start=0xffff
tty=true

[hardware.segment.ram]
kind=ram
start=0x0
size=0xfffe
```
