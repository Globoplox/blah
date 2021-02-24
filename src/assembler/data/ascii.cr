require "./data"

class RiSC16::Assembler::Data::Ascii < RiSC16::Assembler::Data
  @bytes : Bytes
  
  def initialize(parameters)
    raise "String is not ascii only" unless parameters.ascii_only?
    match = /^"(?<str>.*)"$/.match parameters.strip
    raise "Bad parameter for string data statement: '#{parameters}'" unless match
    str = match["str"]
    str = str.gsub /[^\\]\\\\/ { "/" }
    str = str.gsub /\\n/ { "\n" }
    str = str.gsub /\\0/ { "\0" }
    @bytes = str.to_slice
  end
  
  def stored
    (@bytes.size / 2).ceil.to_u16
  end
  
  def solve(base_address, indexes)
  end
  
  def write(io)
    io.write @bytes
    0u8.to_io io, IO::ByteFormat::LittleEndian if @bytes.size.odd?
  end
end
