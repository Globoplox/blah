require "../risc16"

module RiSC16::Assembler
  extend self
  
  # Error emitted in case of error during assembly.
  class Exception < ::Exception
    def initialize(@unit : String?, @line : Int32?, cause)
      super("Assembler stopped in unit #{@unit || "???"} at line #{@line || "???"}: \n\t#{cause.message}", cause: cause)
    end
  end
  
  # Represent any kind of meaningful statement that need further processing.
  module Statement
    # Perform check and prepare for writing.
    abstract def solve(base_address, indexes)
    # Write the statement equivalent bitcode to io.
    abstract def write(io)
    # Return the expected size in words of the bitcode.
    abstract def stored    
  end
end

require "./parser"
require "./complex"
require "./instruction"
require "./pseudo"
require "./data"
require "./loc"
require "./unit"

module RiSC16::Assembler
  # Read the sources files, assemble them and write the result to target. 
  def self.assemble(sources, target, spec)
    raise "No source file provided" unless sources.size > 0
    raise "Providing mutliples sources file is not supported yet." if sources.size > 1
    predefined_symbols = {} of String => Word
    predefined_symbols["__stack"] = spec.stack_start
    spec.io.each do |io|
      absolute = spec.io_start + io.index
      relative = ((2 ** 7) + (absolute.to_i32 - (UInt16::MAX.to_u32 + 1)).bits(0...6)).to_u16
      predefined_symbols["__io_#{io.name}_a"] = absolute
      predefined_symbols["__io_#{io.name}_r"] = relative
    end
    Assembler::Unit.new.tap do |unit|
      File.open sources.first, mode: "r" do |input| 
        unit.parse input, name: sources.first
      end
      unit.index predefined_symbols
      unit.solve
      if target.is_a? String
        File.open target, mode: "w" do |output|
          unit.write output
        end
      else
        unit.write target
      end 
    end
  end
end
