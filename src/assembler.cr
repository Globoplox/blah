require "./risc16"

module RiSC16

  # Assembler namespace.
  # Holds various parsing helper function.
  module Assembler
    extend self

    # Error emitted in case of error during assembly.
    class Exception < ::Exception
      def initialize(exception, @unit : String? = nil, @line : Int32? = nil)
        super(exception)
      end
    end

    # Pseudo instruction set
    enum PISA
      Nop
      Halt
      Lli
      Movi
    end      

    # Represent data
    class Data
      def assembly_size
        0
      end

      def solve(base_address, indexes)
      end

      def self.parse(operation, parameters)
      end
    end
 
    # Represent an instruction in the program (as code).
    class Instruction < RiSC16::Instruction
      property complex_immediate : { String?, Int32, Bool }? = nil

      def self.parse(operation : ISA, parameters): self
        case operation
        in ISA::Add, ISA::Nand
          a,b,c = Assembler.parse_rrr parameters
          Instruction.new operation, reg_a: a, reg_b: b, reg_c: c
        in ISA::Addi, ISA::Sw, ISA::Lw, ISA::Beq
          a,b,i = Assembler.parse_rri parameters
          Instruction.new operation, reg_a: a, reg_b: b, complex_immediate: i
        in ISA::Lui
          a,i = Assembler.parse_ri parameters
          Instruction.new operation, reg_a: a, complex_immediate: i
        in ISA::Jalr
          a,b,i = Assembler.parse_rri parameters, no_i: true
          Instruction.new operation, reg_a: a, reg_b: b
        end
      end  

      def initialize(@op : ISA, @reg_a : UInt16 = 0_u16, @reg_b : UInt16 = 0_u16, @reg_c : UInt16 = 0_u16, @immediate : UInt16 = 0_u16, @complex_immediate : { String?, Int32, Bool } | Nil = nil)
      end
 
      def solve(base_address, indexes)
        @complex_immediate.try do |complex|
          @immediate = Assembler.solve_immediate complex, indexes, bits: (@op.jalr? ? 10 : 7), signed: !@op.jalr?, relative_to: (@op.beq? ? base_address : nil)
        end
      end
      
    end
    
    # A pseudo instruction
    class Pseudo
      property operation : PISA
      property parameters : String

      def initialize(@operation, @parameters) end

      def assembly_size
        case operation
        in PISA::Nop then 1
        in PISA::Halt then 1
        in PISA::Lli then 1
        in PISA::Movi then 2
        end
      end
    
      def solve(base_address, indexes)
        case operation
        in PISA::Nop then [Instruction.new ISA::Add, reg_a: 0_u16 ,reg_b: 0_u16, reg_c: 0_u16]
        in PISA::Halt then [Instruction.new ISA::Jalr, reg_a: 0_u16 , reg_b: 0_u16, immediate: 1_u16 ]
        in PISA::Lli
            a,immediate = Assembler.parse_ri parameters
            offset = Assembler.solve_immediate immediate, indexes, bits: 16, signed: true
            [Instruction.new ISA::Addi, reg_a: a, reg_b: a, immediate: offset & 0x3f_u16 ]
        in PISA::Movi
            a,immediate = Assembler.parse_ri parameters
            offset = Assembler.solve_immediate immediate, indexes, bits: 16, signed: true
            [Instruction.new(ISA::Lui, reg_a: a, immediate: offset >> 6),
             Instruction.new(ISA::Addi, reg_a: a, reg_b: a, immediate: offset & 0x3f_u16)]
        end
      end
    end
   
    def self.solve_immediate(immediate, indexes, bits, signed, relative_to = nil): UInt16
      label, offset, is_negativ = immediate
      label_value =  label.try { |label| indexes[label]?.try &.base_address! || raise "Unknown label '#{label}'" } || 0_u16
      result = if relative_to
          (label_value.to_i32 - relative_to - 1) + (offset * (is_negativ ? -1 : 1))
        else
          label_value.to_i32 + (is_negativ ? -offset : offset)
      end
      result = if signed
        if result < 0
          (-result - 1).to_u16 | 1 << (bits - 1)
        else
          result.to_u16
        end
      else
        raise "Immediate result '#{result}' is illegal negative value" if result < 0
        result.to_u16
      end
      raise "Immediate result #{result} overflow from store size of #{bits} bits" if result & ~0 << bits != 0
      result
    end
    
    def self.parse_immediate(raw : String): {String?, Int32, Bool }
      immediate = /^(?<label>:[A-Z_][A-Z_0-9]*)?((?<mod>\+|-)?(?<offset>(0x|0b|(0))?[A-F_0-9]+))?$/i.match raw
      raise "Bad immediate '#{raw}'" if immediate.nil?
      label = immediate["label"]?.try &.lchop ':'
      offset = immediate["offset"]?
      raise "Invalid immediate '#{raw}'" unless label || offset
      offset = offset.try &.to_i32(underscore: true, prefix: true) || 0
      { label, offset, immediate["mod"]? == "-" && offset != 0 }
    end
          
    def self.parse_rrr(params)
      arr = params.split /\s+/, remove_empty: true
      raise "Unexpected rrr parameters amount: found #{arr.size}, expected 3" unless arr.size == 3
      arr = arr.map do |register| register.lchop?('r') || register end
      { arr[0].to_u16, arr[1].to_u16, arr[2].to_u16 }
    end
    
    def self.parse_rri(params, no_i = false)
      arr = params.split /\s+/, remove_empty: true
      raise "Unexpected rri type parameters amount: found #{arr.size}, expected #{no_i ? 2 : 3}" unless arr.size == 3 || (no_i && arr.size == 2)
      arr = arr.map do |register| register.lchop?('r') || register end
      { (arr[0].lchop?('r') || arr[0]).to_u16, (arr[1].lchop?('r') || arr[1]).to_u16, no_i ? { nil, 0, false } : parse_immediate arr[2] }
    end
    
    def self.parse_ri(params)
      arr = params.split /\s+/, remove_empty: true
      raise "Unexpected ri type parameters amount: found #{arr.size}, expected 2" unless arr.size == 2
      arr = arr.map do |register| register.lchop?('r') || register end
      { (arr[0].lchop?('r') || arr[0]).to_u16, parse_immediate arr[1] }
    end

    # Represent a line of code in a program.
    # A line can hold various combinaisons of elements:
    # comment, label, a data statement, an instruction or a pseudo-instruction.
    # Base address represent the address at which the hypothetical data or instruction would be stored in memory.
    class Loc
      property source : String
      property file : String? = nil
      property line : Int32? = nil
      property data : Data? = nil
      property instructions = [] of Instruction
      property pseudo : Pseudo? = nil
      property label : String? = nil
      property comment : String? = nil
      property base_address : UInt16? = nil

      def base_address!
        @base_address.not_nil!
      end
      
      def initialize(@source, @file = nil, @line = nil)
        lm = /^((?<label>[a-z0-9_]+):)?\s*((?<operation>[A-Za-z._]+)(\s+(?<parameters>[^#]*))?)?\s*(?<comment>#.*)?$/i.match @source
        raise "Syntax Error" if lm.nil?
        @label = lm["label"]?  
        @comment = lm["comment"]?
        operation = lm["operation"]?
        if operation
          parameters = lm["parameters"]? || ""
          if operation.starts_with? '.'
            @data = Data.parse operation.lchop, parameters
          elsif ISA.names.map(&.downcase).includes? operation
            @instructions << Instruction.parse ISA.parse(operation), parameters
          elsif PISA.names.map(&.downcase).includes? operation
            @pseudo = Pseudo.new PISA.parse(operation), parameters
          else
            raise "Unknown operation '#{operation}'"
          end
        end
      end
      
      def assembly_size
        @data.try(&.assembly_size) || @pseudo.try(&.assembly_size) || @instructions.size
      end
      
      def solve(indexes)
        @data.try &.solve base_address!, indexes
        @pseudo.try do |pseudo|
          @instructions = pseudo.solve base_address!, indexes
        end
        @instructions.each_with_index do |instruction, index|
          instruction.solve base_address! + index, indexes
        end
      end
        
    end

    # Represent a collection of line of code.
    # Maybe will support a kind of linking.
    # Line of codes can references each others in the same unit.
    # Currently an unit assume it is loaded at 0.
    class Unit
      @program = [] of Loc
      @indexes = {} of String => Loc
    
      getter program
            
      def initialize() end

      # Parse the diffrent lines of codes in the given io.
      def parse(io : IO, name : String? = nil)
        i = 0
        io.each_line do |line|
          line = line.strip
          begin
            @program << Loc.new source: line, file: name, line: i
          rescue ex
            raise Exception.new ex.message, name, i
          end
          i += 1
        end
      end

      # Build an index for solving references.
      def index
        i = 0_u16
        @indexes.clear
        @program.each do |loc|
          begin
            loc.base_address = i
            loc.label.try { |label| @indexes[label] = loc }
            i += loc.assembly_size.to_u16
          rescue ex
            raise Exception.new ex.message, loc.file, loc.line
          end
        end
      end

      # Solve references and develop pseudo-instructions.
      def solve
        @program.each do |loc|
          begin
            loc.solve @indexes
          rescue ex
            raise Exception.new ex.message, loc.file, loc.line
          end
        end
      end

      def write(io)
        program.map(&.instructions).flatten.each do |instruction|
          instruction.encode.to_io io, IO::ByteFormat::LittleEndian
        end
      end
    end

    def self.assemble(sources, target, debug = false)
      raise "No source file provided" unless sources.size > 0
      raise "Providing mutliples sources file is not supported yet." if sources.size > 1
      Assembler::Unit.new.tap do |unit|
        File.open sources.first, mode: "r" do |input| 
          unit.parse input
        end
        unit.index
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
end
