require "./data"

# a word per chararcter, no null terminator
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
    @bytes.size
  end
  
  def solve(base_address, indexes)
  end
  
  def write(io)
    @bytes.each do |byte| 
      byte.to_u16.to_io io, IO::ByteFormat::BigEndian
    end
  end
end
