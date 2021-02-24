require "../assembler"
require "../instruction"
require "../parser"

# Represent a pseudo instruction.
abstract class RiSC16::Assembler::Pseudo
  include Statement
  @instructions = [] of Instruction
  
  def write(io)
    @instructions.each &.write io
  end

  OPERATIONS = ["nop", "halt", "lli", "movi", "call", "function", "return"]
end

require "./nop"
require "./halt"
require "./lli"
require "./movi"
require "./call"
require "./return"
require "./function"

abstract class RiSC16::Assembler::Pseudo
  def self.new(operation, parameters)
    case operation
    when "nop" then Nop.new parameters
    when "halt" then Halt.new parameters
    when "lli" then Lli.new parameters
    when "movi" then Movi.new parameters
    when "call" then Call.new parameters
    when "return" then Return.new parameters
    when "function" then Function.new parameters
    end
  end  
end
