require "stdlib/putword.sl"

var my_global
var buffer: [12]
var my_global_b

struct Long { a;b;c;d }

fun main:_ {
  var a: Long
  var b: Long
  a.b = -6
  b = a
  buffer[1 + 2] = my_global = 0xf876 + b.b
  putword(*(&my_global))
  return 0
}