require "../assembler"

# Represent a data statement.
abstract class RiSC16::Assembler::Data
  include Statement
  
  class Word < Data
    @complex : Complex
    @word : UInt16 = 0
    def initialize(parameters)
      @complex = Assembler.parse_immediate parameters
    end
    
    def stored
      1
    end
    
    def solve(base_address, indexes)
      @word = @complex.solve indexes, bits: 16
    end
    
    def write(io)
      @word.to_io io, IO::ByteFormat::LittleEndian
    end
  end
  
  class Ascii < Data
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
  
  def self.new(operation, parameters)
    case operation
    when ".word" then Word.new parameters
    when ".ascii" then Ascii.new parameters
    end
  end
  
end  
