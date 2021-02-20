require "./risc16"

module RiSC16

  # Assembler namespace.
  # Holds various parsing helper function.
  module Assembler
    extend self

    # Error emitted in case of error during assembly.
    class Exception < ::Exception
      def initialize(@unit : String?, @line : Int32?, cause)
        super("Assembler stopped in unit #{@unit || "???"} at line #{@line || "???"}", cause: cause)
      end
    end

    def self.parse_immediate(raw : String): Complex
      immediate = /^(?<label>:[A-Z_][A-Z_0-9]*)?((?<mod>\+|-)?(?<offset>(0x|0b|(0))?[A-F_0-9]+))?$/i.match raw
      raise "Bad immediate '#{raw}'" if immediate.nil?
      label = immediate["label"]?.try &.lchop ':'
      offset = immediate["offset"]?
      raise "Invalid immediate '#{raw}'" unless label || offset
      offset = offset.try &.to_i32(underscore: true, prefix: true) || 0
      Complex.new label, offset, immediate["mod"]? == "-" && offset != 0
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
      { (arr[0].lchop?('r') || arr[0]).to_u16, (arr[1].lchop?('r') || arr[1]).to_u16, no_i ? Complex.new(nil, 0, false) : parse_immediate arr[2] }
    end
    
    def self.parse_ri(params)
      arr = params.split /\s+/, remove_empty: true
      raise "Unexpected ri type parameters amount: found #{arr.size}, expected 2" unless arr.size == 2
      arr = arr.map do |register| register.lchop?('r') || register end
      { (arr[0].lchop?('r') || arr[0]).to_u16, parse_immediate arr[1] }
    end

    module Statement
      abstract def solve(base_address, indexes)
      abstract def write(io)
      abstract def stored    
    end

    class Complex
      property label : String?
      property offset : Int32
      property complement : Bool
      
      def initialize(@label = nil, @offset = 0, @complement = false)
      end
      
      def solve(indexes, bits, relative_to = nil): UInt16
        label_value =  @label.try { |label| indexes[label]?.try &.[:address] || raise "Unknown label '#{label}'" } || 0_u16
        result = if relative_to
                   (label_value.to_i32 - relative_to - 1) + (@offset * (@complement ? -1 : 1))
                 else
                   label_value.to_i32 + (@complement ? -@offset : @offset)
                 end
        result = if result < 0
                   # Uncomment to disallow overflow (rotate otherwise). Usefull in case of programatic offset that could inadvertedly overflow
                   # raise "Immediate result #{result} complement two will overflow from store size of #{bits} bits" if -result > (2 ** (bits - 1))
                   ((2 ** bits) + result.bits(0...(bits- 1))).to_u16
                 else
                   result.to_u16
                 end
        raise "Immediate result #{result} overflow from store size of #{bits} bits" if result & ~0 << bits != 0
        result
      end
      
    end
    
    # Represent an instruction in the program (as code).
    class Instruction < RiSC16::Instruction
      include Statement
      property complex_immediate : Complex? = nil

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

      def initialize(@op : ISA, @reg_a : UInt16 = 0_u16, @reg_b : UInt16 = 0_u16, @reg_c : UInt16 = 0_u16, @immediate : UInt16 = 0_u16, @complex_immediate : Complex? = nil)
      end
 
      def solve(base_address, indexes)
        @immediate = @complex_immediate.try(&.solve(indexes, bits: (@op.lui? ? 10 : 7), relative_to: (@op.beq? ? base_address : nil))) || @immediate
      end

      def write(io)
        encode.to_io io, IO::ByteFormat::LittleEndian
      end
      
      def stored
        1u16
      end
      
    end
    
    # A pseudo instruction
    class Pseudo
      include Statement
      property operation : PISA
      property parameters : String
      @instructions = [] of Instruction

      # Pseudo instruction set
      enum PISA
        Nop
        Halt
        Lli
        Movi
      end
      
      def initialize(@operation, @parameters) end

      def stored
        case operation
            in PISA::Nop then 1u16
            in PISA::Halt then 1u16
            in PISA::Lli then 1u16
            in PISA::Movi then 2u16
        end
      end
    
      def solve(base_address, indexes)
        @instructions = case operation
          in PISA::Nop then [Instruction.new ISA::Add, reg_a: 0_u16 ,reg_b: 0_u16, reg_c: 0_u16]
          in PISA::Halt then [Instruction.new ISA::Jalr, reg_a: 0_u16 , reg_b: 0_u16, immediate: 1_u16 ]
          in PISA::Lli
            a,immediate = Assembler.parse_ri parameters
            offset = immediate.solve indexes, bits: 16
            [Instruction.new ISA::Addi, reg_a: a, reg_b: a, immediate: offset & 0x3f_u16 ]
          in PISA::Movi
            # TODO: if offset & 01111111 == 0 then the addi part is useless and it can be omitted.
            a,immediate = Assembler.parse_ri parameters
            offset = immediate.solve indexes, bits: 16
            [Instruction.new(ISA::Lui, reg_a: a, immediate: offset >> 6),
             Instruction.new(ISA::Addi, reg_a: a, reg_b: a, immediate: offset & 0x3f_u16)]
        end
      end

      def write(io)
        @instructions.each &.write io
      end

    end    

    # Represent a line of code in a program.
    # A line can hold various combinaisons of elements:
    # comment, label, a data statement, an instruction or a pseudo-instruction.
    # Base address represent the address at which the hypothetical data or instruction would be stored in memory.
    class Loc
      property source : String
      property file : String? = nil
      property line : Int32? = nil
      property label : String? = nil
      property comment : String? = nil

      property statement : Statement? = nil
      
      def base_address!
        @base_address.not_nil!
      end


      def initialize(@source, @file = nil, @line = nil)
      end
      
      def parse
        lm = /^((?<label>[a-z0-9_]+):)?\s*((?<operation>[A-Za-z._]+)(\s+(?<parameters>[^#]*))?)?\s*(?<comment>#.*)?$/i.match @source
        raise "Syntax Error" if lm.nil?
        @label = lm["label"]?  
        @comment = lm["comment"]?
        operation = lm["operation"]?

        if operation
          parameters = lm["parameters"]? || ""
          if ISA.names.map(&.downcase).includes? operation
            @statement = Instruction.parse ISA.parse(operation), parameters
          elsif Pseudo::PISA.names.map(&.downcase).includes? operation
            @statement = Pseudo.new Pseudo::PISA.parse(operation), parameters
          else
            raise "Unknown operation '#{operation}'"
          end
        end
      end
      
      def stored
        @statement.try &.stored || 0u16
      end
      
      def solve(base_address, indexes)
        @statement.try &.solve base_address, indexes
      end
        
    end

    # Represent a collection of line of code.
    # Maybe will support a kind of linking.
    # Line of codes can references each others in the same unit.
    # Currently an unit assume it is loaded at 0.
    class Unit
      @program = [] of Loc
      @indexes = {} of String => {loc: Loc, address: UInt16}
      getter program
            
      def error(cause, name, line)
        Exception.new name, line, cause
      end

      # Parse the diffrent lines of codes in the given io.
      def parse(io : IO, name = nil)
        i = 1
        io.each_line do |line|
          line = line.strip
          begin
            loc = Loc.new source: line, file: name, line: i
            loc.parse
            @program << loc
          rescue ex
            raise error ex, name, i
          end
          i += 1
        end
      end

      # Iterate statelement with their expected loading address (relative to unit)
      def each_with_address
        @program.reduce(0u16) do |address, loc|
          begin
            yield address, loc
          rescue ex
            raise error ex, loc.file, loc.line
          end
          address + loc.stored
        end
      end
      
      # Build an index for solving references.
      def index
        @indexes.clear
        each_with_address do |address, loc|
          loc.label.try { |label| @indexes[label] = {loc: loc, address: address} }
        end
      end

      # Solve references and develop pseudo-instructions.
      def solve
        each_with_address do |address, loc|
          loc.solve address, @indexes
        end
      end
      
      def write(io)
        program.map(&.statement).compact.each &.write io
      end
      
    end

    def self.assemble(sources, target)
      raise "No source file provided" unless sources.size > 0
      raise "Providing mutliples sources file is not supported yet." if sources.size > 1
      Assembler::Unit.new.tap do |unit|

        File.open sources.first, mode: "r" do |input| 
          unit.parse input, name: sources.first
        end

        unit.index

        begin 
          unit.solve
        rescue ex
          puts ex
          ex.cause.try do |cause|
            raise cause
          end
        end

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
