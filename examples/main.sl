require "stdlib/putword.sl"

fun main:_ {
  putword(-23 * 7)
  return 0
}

// var my_global
// var buffer: [12]
// var my_global_b

// struct Long { a;b;c;d }

// fun foo: [2] {
//   var bar : [2]
//   bar[0] = 0xf0
//   bar[1] = 0x0d
//   return bar
// }

// fun main:_ {
//   var foobar : [2] = foo()
//   putword(foobar[0])
//   putword(foobar[1])
//   return 0
//   // var a: Long
//   // var b: Long
//   // a.b = -6
//   // b = a
//   // buffer[1 + 2] = my_global = 0xf876 + b.b
//   // putword(*(&my_global))
//   // return 0
// }