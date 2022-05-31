require "../../stdlib/putword.sl"

struct MBRInfo {
  size
  reserved: [3]
}

fun main:_ {
  putword(((MBRInfo)__section_text_metadata).size)
  __io_tty = 0x20
  putword(((MBRInfo)__section_text_metadata).reserved[0])
  __io_tty = 0x20
  putword(((MBRInfo)__section_text_metadata).reserved[1])
  __io_tty = 0x20
  putword(((MBRInfo)__section_text_metadata).reserved[2])
  __io_tty = 0x20
  return 0x0
}