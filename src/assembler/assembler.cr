require "../risc16"
require "./ast"
require "./parser"
require "./object"

module RiSC16::Assembler
  extend self

  ENDIAN = IO::ByteFormat::BigEndian

  def assemble_immediate(section, address, immediate, kind)
    if symbol = immediate.symbol
      references = section.references[symbol] ||= [] of Object::Section::Reference
      references << Object::Section::Reference.new address.to_u16, immediate.offset, kind
      0u16
    else
      bits = case kind
        when .imm?, .beq? then 7
        else 16
      end       

      value = if immediate.offset < 0
        ((2 ** bits) + immediate.offset.bits(0...(bits - 1))).to_u16
      else
        immediate.offset.to_u16
      end

      value = value >> 6 if kind.lui?

      value
    end
  end
  
  def assemble(unit : AST::Unit) : Object
    current_section = Object::Section.new "text"
    object = Object.new unit.name
    object.sections << current_section
    text = IO::Memory.new
    immediates = [] of {AST::Immediate, Int32, Object::Section::Reference::Kind}
    all_defintions = [] of String # for error management only

    unit.statements.each do |statement|

      statement.section.try do |section|
        text.rewind
        current_section.text = text.gets_to_end.to_slice
        text = IO::Memory.new
        current_section = Object::Section.new section.name, section.offset
        object.sections << current_section
      end

      statement.symbol.try do |label| # could use ast metadata that do not exists yet to add line and column for sources
        raise "Duplicate symbol '#{label}'" if label.in? all_defintions
        all_defintions << label
        current_section.definitions[label] = Object::Section::Symbol.new text.pos.to_u16, statement.exported
      end
     
      statement.instruction.try do |instruction|
        case memo = instruction.memo.downcase
        when "add", "nand"
          reg_a = instruction.parameters[0].as AST::Register
          reg_b = instruction.parameters[1].as AST::Register
          reg_c = instruction.parameters[2].as AST::Register
          Instruction.new(ISA.parse(memo), reg_a.index.to_u16, reg_b.index.to_u16, reg_c.index.to_u16).encode.to_io text, ENDIAN
        when "addi", "sw", "lw", "beq"
          reg_a = instruction.parameters[0].as AST::Register
          reg_b = instruction.parameters[1].as AST::Register
          immediate = instruction.parameters[2].as AST::Immediate
          offset = assemble_immediate current_section, text.pos, immediate, Object::Section::Reference::Kind::Imm
          Instruction.new(ISA.parse(memo), reg_a.index.to_u16, reg_b.index.to_u16, immediate: offset).encode.to_io text, ENDIAN
        when "lui"
          reg_a = instruction.parameters[0].as AST::Register
          immediate = instruction.parameters[1].as AST::Immediate
          offset = assemble_immediate current_section, text.pos, immediate, Object::Section::Reference::Kind::Lui
          Instruction.new(ISA::Lui, reg_a.index.to_u16, immediate: offset).encode.to_io text, ENDIAN
        when "jalr"
          reg_a = instruction.parameters[0].as AST::Register
          reg_b = instruction.parameters[1].as AST::Register
          Instruction.new(ISA::Jalr, reg_a.index.to_u16, reg_b.index.to_u16).encode.to_io text, ENDIAN
        when "nop"
          Instruction.new(ISA::Add).encode.to_io text, ENDIAN
        when "lli"
          reg_a = instruction.parameters[0].as AST::Register
          immediate = instruction.parameters[1].as AST::Immediate
          offset = assemble_immediate current_section, text.pos, immediate, Object::Section::Reference::Kind::Lli
          Instruction.new(ISA::Addi, reg_a.index.to_u16, reg_a.index.to_u16, immediate: offset & 0x3fu16).encode.to_io text, ENDIAN
        when "movi"
          reg_a = instruction.parameters[0].as AST::Register
          immediate = instruction.parameters[1].as AST::Immediate
          offset = assemble_immediate current_section, text.pos, immediate, Object::Section::Reference::Kind::Lui
          Instruction.new(ISA::Lui, reg_a.index.to_u16, immediate: offset).encode.to_io text, ENDIAN
          offset = assemble_immediate current_section, text.pos, immediate, Object::Section::Reference::Kind::Lli
          Instruction.new(ISA::Addi, reg_a.index.to_u16, reg_a.index.to_u16, immediate: offset & 0x3fu16).encode.to_io text, ENDIAN
        when "halt"
          Instruction.new(ISA::Jalr, immediate: 1u16).encode.to_io text, ENDIAN
        when ".word"
          immediate = instruction.parameters[0].as AST::Immediate
          offset = assemble_immediate current_section, text.pos, immediate, Object::Section::Reference::Kind::Data
          offset.to_io text, ENDIAN
        when ".ascii"
          string = instruction.parameters[0].as AST::Text
          string.text.to_slice.each { |byte| byte.to_u16.to_io text, ENDIAN }
        else puts "Unknown statement memo #{memo}"
        end
      end
      
    end

    text.rewind
    current_section.text = text.gets_to_end.to_slice
    object
  end
end

ast =  RiSC16::Assembler::Parser.new(IO::Memory.new(ARGF.gets_to_end), true).unit
if ast 
  object = RiSC16::Assembler.assemble ast 
  if object
    pp object
    pp object.sections.first.text.size
  end
end
