require "utils.sl"

var test: [0x10]
var another: [0x10]_
var yet_another: [0x10]*_
var one_more: [0x10][2]

/* This is a comment */
fun main {
  __io_tty = get_default_char()
  __io_tty = 0x30 + sizeof([6]*_)
  return
}