fun test {
  *0*(**0)
}

/*
require "stdlib/prototypes.sl"


var extern test_global:**_

fun load_io(io:*, destination:*, size):_ {
  my_var

  !my_var

  !~(var + other_var) + var & call(a, b, !c + x) *
   4
   *6
}

var program: [0x100]
var ram: [0x100]

fun main:_ {
  restricted var pc = 0
  restricted var ptr = 0
  var program_size = load_io(&__io_brainfuck, &program, 0x1000) // TODO: make sizeof work with vars ?
  restricted var loop_count = 0

  if (program_size == 0x10)
     return 1

  while (1) {
    if (pc == program_size)
      return 0

    if (program[pc] == 0x3E)
      ptr += 1
      
    if (program[pc] == 0x3c)
      ptr -= 1
      
    if (program[pc] == 0x2B)
      ram[ptr] += 1
      
    if (program[pc] == 0x2D)
      ram[ptr] -= 1
      
    if (program[pc] == 0x2E)
      __io_tty = ram[ptr]
      
    if (program[pc] == 0x2C)
      ram[ptr] = __io_tty

    if (program[pc] == 0x5B) {
      if (ram[ptr] == 0) {
       	while (program[pc] != 0x5D || loop_count != 0) {
 	  pc += 1
	  if (pc == program_size)
      	    return 1
	  if (program[pc] == 0x5B)
	    loop_count += 1
	  if (program[pc] == 0x5D)
	    loop_count -= 1
        }
      }
    }
       
    if (program[pc] == 0x5D) {
      if (ram[ptr] != 0) {
        loop_count = 1
       	while (program[pc] != 0x5B || loop_count != 0) {
          if (pc == 0)
	    return 1
	  pc -= 1
	  if (program[pc] == 0x5D)
	    loop_count += 1
	  if (program[pc] == 0x5B)
	    loop_count -= 1
	}
      }
    }

    pc += 1
  }
  return 0
}
  */