require "../../stdlib/prototypes"

fun load_io(io:*, destination:*, size):_ {

  var i = 0
  var buffer
  while ((buffer = *io) != 0xff00) {
    if (i == size)
      return 0
    *(destination + i) = buffer
    i += 1
  }
  return i
}

fun noop(a:*) {}

fun test {
  noop(1)
}

var program: [0x100]
var ram: [0x100]

fun main:_ {
  var pc = 0
  var ptr = 0
  var program_size = load_io(&__io_brainfuck, &program, 0x100)
  var loop_count = 0

  if (program_size == 0x100) /* If we have not loaded the whole program because we ran out of space */
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