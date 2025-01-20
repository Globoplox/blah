/*
var a
var b

struct S { j k }

fun other(i : S):_ {
  var a = i.k
}
*/
  
/*
// Works well without any garbage
fun main:_ {
  var b = 3
  var c = 5
  var a = b + c  
  return a
}*/

// Works well and is pretty smart about reusing literal values and rotating registers
fun main:_ {
  return 1 + 1 + 1 + 1 + 1 +1 +1 +1 +1 +2 +3 +4 +5 +6 +1 +6
}

/*
fun foo:S {
  var bar : S
  bar.j = other(bar)
  return bar
}
*/