fun main {
  var buffer
  while ((buffer = __io_tty) != 0xff00)
    __io_tty = buffer
  return
}