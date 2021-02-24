require "../assembler"

# Represent a data statement.
abstract class RiSC16::Assembler::Data
  include Statement
end

require "./word"
require "./ascii"

abstract class RiSC16::Assembler::Data

  def self.new(operation, parameters)
    case operation
    when ".word" then Word.new parameters
    when ".ascii" then Ascii.new parameters
    end
  end
  
end  
