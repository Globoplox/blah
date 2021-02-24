require "./data"

# Represent a data statement.
class RiSC16::Assembler::Data::Word < RiSC16::Assembler::Data
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
