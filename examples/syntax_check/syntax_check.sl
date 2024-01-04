require "utils"

var test: [0x10]
var another: [0x10]_
var yet_another: [0x10]*_
var one_more: [0x10][2]

struct CustomType {
  foo
  baz:[0x5]
  bar:*
}

/* This is a comment */
fun main {
  __io_tty = get_default_char()
  /* 
    a comment 
    /* a nested comment */
  */
  __io_tty = 0x30 + sizeof([6]*_)
  /* 
    Print value stored at address 19, which with current startup code is
    a hexadecimal char 
  */
  __io_tty = *cast(*, 19)

  if (1)
    __io_tty = 0x31

  if (0) {
    __io_tty = 0x32
  }

  if (0x1337) { __io_tty = 0x33 }

  if (0x1337) __io_tty = 0x34

  /* 
    I have not implemented variables yet 
    So I will just use the word at address 1337 as my var
  */
  
  *cast(*, 1337) = 4
  while (*cast(*, 1337)) {
    __io_tty = 0x30 + *cast(*, 1337)
    *cast(*, 1337) -= 1
  }

  var foo = *&bar
  var bar = 4
  __io_tty = 0x30 + foo
  foo = 9
  __io_tty = 0x30 + foo
  __io_tty = 0x30 + bar

  var c: CustomType

  c.bar = &c.foo
  c.foo = 2
  __io_tty = 0x30 + *c.bar
  __io_tty = 0x30 + (cast(_, &c.bar) - cast(_, &c.foo)) - 1 /* This will output the size of c.baz */

  return
}