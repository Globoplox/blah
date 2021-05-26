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
require "./linker"

module RiSC16::Assembler
  
  # Read the sources files, assemble them and write the result to target. 
  def self.assemble(sources, target, spec)
    raise "No source file provided" unless sources.size > 0

    units = sources.map do |input|
      Assembler::Unit.new.tap do |unit|
        File.open input, mode: "r" do |input|
          unit.parse input, name: sources.first
        end
      end
    end

    if target.is_a? String
      File.open target, mode: "w" do |output|
        Linker.links_to_bitcode spec, units, output
      end
    else
      Linker.links_to_bitcode spec, units, target
    end

    units
  end
end
