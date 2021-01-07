# https://user.eng.umd.edu/~blj/RiSC/RiSC-isa.pdf
# DONE # Indexing store expected memory location in LOC
# DONE # More complex immediate: label+-offset, specify if rlative to pc or not (current default to absolute unless param to beq)
# Data statements
# Assembly time linking (mergeing multiples units and external references)
# # This needs:
# # - statement for defining external symbol
# # - a main unit (to put first)
# # - Linking happen before solving units
# # - Base-Address of all LOC in linked units are pushed as necessary before solving
# # - Index of all units are fed the external index of referenced
# # - An assembly time check at solving that verify that there are no arithmetic overflow when solving labels references (including for pseudi lli)
# # # - Overflow check on final result after solving
# # - Maybe a assembler entry point grabbing multiple files (sepcifying main unit)
# # - Maybe a assembler statement asking to require another file as unit
# Special RW: IO
# Fault (bad address, overflow, write to r0) and interrupt (interrupt code added in predefined memory protected area ?)
# # This need to waste a register for storing the return address.
# Now we have a "runtime" for the proc maybe we can make a micro kernel: system lib, syscall, runtime linking and loading of program with a more complex file structure.
# # Runtime linking would: loading a program and replacing external ref with those of a previously laoded library.
# Program could be given an indicative memory section to sray in (wont be enforced).
# Subdivision or ram in io, firmware (interrupts), kernel & syscall, and programsLlibs area.
# Program could ask for a ram amount and a priority. Syscall would allow for kernel code to decide, with priority of which program to resume next.
# # Nothing would be safe without memory proptection but still fun.
# # The loaded code need to be aware that iy has a dynamic base_address and should probably keep it in a register.
# Finally we would want a minimalistic stack based language.
# Tool for editing, debuging, desassembling.
module RiSC16
  VERSION = "0.1.0"
  
  alias Word = UInt16

  REGISTER_COUNT = 8
  MAX_MEMORY_SIZE = UInt16::MAX

  #not tested yet
  class VM
    property ram : Array(UInt16)
    property registers = Array(UInt16).new REGISTER_COUNT
    property pc = 0
    
    def initialize(ram_size)
      @ram = Array(UInt16).new ram_size
    end
    
    def load(program, at = 0)
      program.each_byte do |byte|
        ram[at] = byte
        at += 1
      end
    end

    def step
      instruction = ram[@pc]
      opcode = ISA.from_value instruction >> 13
      case opcode
      when Add then registers[(instruction >> 10) & 0b111] = regsiters[(instruction >> 7) & 0b111] + registers[instruction 0b111]
      when Addi then registers[(instruction >> 10) & 0b111] = regsiters[(instruction >> 7) & 0b111] + (instruction & 0b111111) * ((instruction >> 6) & 1 ? -1 : 0)
      when Nand then registers[(instruction >> 10) & 0b111] = ~(regsiters[(instruction >> 7) & 0b111] & registers[instruction 0b111])
      when Lui then registers[(instruction >> 10) & 0b111] = (instruction & 0b1111111111) << 6
      when Sw then ram[regsiters[(instruction >> 7) & 0b111] + (instruction & 0b111111) * ((instruction >> 6) & 1 ? -1 : 0)] = registers[(instruction >> 10) & 0b111]
      when Beq then @pc += (instruction & 0b111111) * ((instruction >> 6) & 1 ? -1 : 0) if regsiters[(instruction >> 10) & 0b111] == regsiters[(instruction >> 7) & 0b111]
      when Jalr
        registers[(instruction >> 10) & 0b111] = @pc + 1
        @pc = regsiters[(instruction >> 7) & 0b111]
      end
      @pc += 1 unless opcode.jalr?
      registers[0] = 0
    end
  end

  # Instruction set
  enum ISA
    Add = 0b000
    Addi = 0b001
    Nand = 0b010
    Lui = 0b011 
    Sw = 0b100
    Lw = 0b101
    Beq = 0b110
    Jalr = 0b111
  end

  # An instruction.
  # Does not perform sanity checks at construction.
  class Instruction
    getter op : ISA
    getter reg_a : UInt16
    getter reg_b : UInt16
    getter reg_c : UInt16
    getter immediate : UInt16
    
    def initialize(@op, @reg_a = 0_u16, @reg_b = 0_u16, @reg_c = 0_u16, @immediate = 0_u16) end

    def word
      instruction = @op.value.to_u16 << 13
      case @op
      when ISA::Add, ISA::Nand then instruction |= ((@reg_a & 0b111) << 10) | ((@reg_b & 0b111) << 7) | @reg_c & 0b111
      when ISA::Addi, ISA::Sw, ISA::Lw, ISA::Beq, ISA::Jalr then instruction |= ((@reg_a & 0b111) << 10) | ((@reg_b & 0b111) << 7) | (@immediate & 0b11_1111) | ((@immediate < 0 ? 1 : 0) << 6)
      when ISA::Lui then instruction |= ((@reg_a & 0b111) << 10) | (@immediate & 0b_11_1111_1111)
      end
      pp "#{@op.value.to_s base: 2}(#{(@reg_a & 0b111).to_s base: 2},#{@reg_b.to_s base: 2},#{@reg_c.to_s base: 2},#{@immediate.to_s base: 2}) = 0b#{instruction.to_s base: 2}"
      instruction
    end

    # def self.decode(word)
    #   op = ISA.parse (word >> 13) & 0b111
    #   reg_a, reg_b, reg_c, immediate = case op
    #   when ISA::Add, ISA::Nand then { (word >> 10) & 0b111, (word >> 7) & 0b111, word & 0b111, 0 }
    #   when ISA::Addi, ISA::Sw, ISA::Lw, ISA::Beq, ISA::Jalr then word |= ((reg_a & 0b111) << 10) | ((reg_b & 0b111) << 7) | (word & 0b111111) | ((word < 0 ? 1 : 0) << 6)
    #   when ISA::Lui then { (word >> 10) & 0b111, (word >> 7) & 0b111, 0, (word & 0b111111) & ((word & 0b1000000) << 8) }
    #   end
    #   {op, reg_a, reg_b, reg_c, immediate}
    # end
    
  end

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
      # Address to resolve that must be added to the immediate when solving.
      # Absolute unless op is beq, then relative to pc (so then relative to base_address).
      property label : String? = nil

      def self.parse(operation : ISA, parameters): self
        case operation
        in ISA::Add, ISA::Nand
          a,b,c = Assembler.parse_rrr parameters
          Instruction.new operation, reg_a: a, reg_b: b, reg_c: c
        in ISA::Addi, ISA::Sw, ISA::Lw, ISA::Beq
          a,b,i = Assembler.parse_rri parameters
          Instruction.new operation, reg_a: a, reg_b: b, immediate: i
        in ISA::Lui
          a,i = Assembler.parse_ri parameters
          Instruction.new operation, reg_a: a, immediate: i
        in ISA::Jalr
          a,b,i = Assembler.parse_rri parameters, no_i: true
          Instruction.new operation, reg_a: a, reg_b: b
        end
      end  

      def initialize(op : ISA, reg_a : UInt16 = 0_u16, reg_b : UInt16 = 0_u16, reg_c : UInt16 = 0_u16, immediate : { String?, UInt16 } | Nil = nil)
        if immediate
          label, offset = immediate
          super(op: op, reg_a: reg_a, reg_b: reg_b, reg_c: reg_c, immediate: offset)
          @label = label
        else
          super(op: op, reg_a: reg_a, reg_b: reg_b, reg_c: reg_c)
        end
      end

      def solve(base_address, indexes)
        @label.try do |label|
          if @op.beq?
            @immediate += (indexes[label]?.try &.base_address! || raise "Unknown label '#{label}'") - base_address + 1
          else
            @immediate += indexes[label]?.try &.base_address! || raise "Unknown label '#{label}'"
          end
        end
        @label = nil
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
        in PISA::Halt then [Instruction.new ISA::Jalr, reg_a: 0_u16 , reg_b: 0_u16, immediate: { nil, 0xff_u16}]
        in PISA::Lli
          a,immediate = Assembler.parse_ri parameters
          label, offset = immediate
          offset = offset + (label.try { |label| indexes[label]?.try &.base_address! || raise "Unknown label '#{label}'" } || 0_u16)
          [Instruction.new ISA::Addi, reg_a: a, reg_b: a, immediate: { nil, offset & 0x3f_u16 } ]
        in PISA::Movi
          a,immediate = Assembler.parse_ri parameters
          label, offset = immediate
          offset = offset + (label.try { |label| indexes[label]?.try &.base_address! || raise "Unknown label '#{label}'" } || 0_u16)
          [Instruction.new(ISA::Lui, reg_a: a, immediate: { nil, offset >> 6 }),
           Instruction.new(ISA::Addi, reg_a: a, reg_b: a, immediate: { nil, offset & 0x3f_u16 })]
        end
      end
    end
    
    def self.parse_immediate(raw : String): {String?, UInt16}
      immediate = /^(?<label>:[A-Z_][A-Z_0-9]*)?((?<mod>\+|-)?(?<offset>(0x|0b|0)?[A-F_0-9]+))?$/i.match raw
      raise "Bad immediate '#{raw}'" if immediate.nil?
      label = immediate["label"]?.try &.lchop ':'
      offset = immediate["offset"]?
      raise "Invalid immediate '#{raw}'" unless label || offset
      mod = immediate["mod"]? == "-" ? 1_u16 : 0_u16
      offset = offset.try &.to_u16(underscore: true, prefix: true) || 0_u16
      offset |= mod << 16 if offset != 0                        
      { label, offset }
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
      { (arr[0].lchop?('r') || arr[0]).to_u16, (arr[1].lchop?('r') || arr[1]).to_u16, no_i ? { nil, 0_u16 } : parse_immediate arr[2] }
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
        @instructions.each &.solve base_address!, indexes
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
      
      def self.parse(io : IO)
        new.tap do |unit|
          unit.parse io
          uint.index
          unit.solve
        end
      end
      
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
        program.map(&.instructions).flatten.each do |it|
          io.write_bytes it.word, IO::ByteFormat::BigEndian # it.word.to_io io, IO::ByteFormat::BigEndian
        end
      end
    end
  end
  
  unit = Assembler::Unit.new
  if ARGV.size > 1
    unit.parse File.open ARGV[1]
  else
    unit.parse STDIN
  end
  unit.index
  unit.solve
  output = File.open "a.out", mode: "w", encoding: "binary"
  unit.write output
  output.close
  # load, step, debug
end
