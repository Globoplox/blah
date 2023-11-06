require "../risc16"
require "./ast"
require "./object"

module RiSC16::Assembler
  extend self

  def assemble_immediate(section, address, immediate, kind)
    if symbol = immediate.symbol
      references = section.references[symbol] ||= [] of Object::Section::Reference
      references << Object::Section::Reference.new address.to_u16, immediate.offset, kind
      0u16
    else
      bits = case kind
             when .imm?, .beq? then 7
             else                   16
             end
      value = (immediate.offset < 0 ? (2 ** bits) + immediate.offset.bits(0...(bits - 1)) : immediate.offset).to_u16
      value = value >> 6 if kind.lui?
      value = value & 0x3fu16 if kind.lli?
      value
    end
  end

  def assemble(unit : AST::Unit) : Object
    current_section = Object::Section.new "text"
    object = Object.new unit.name
    object.sections << current_section
    text = [] of UInt16
    immediates = [] of {AST::Immediate, Int32, Object::Section::Reference::Kind}
    all_defintions = {} of String => AST::Statement

    unit.statements.each do |statement|
      statement.section.try do |section|
        current_section.text = Slice.new text.size do |i|
          text[i]
        end
        text.clear
        options = Object::Section::Options::None
        options |= Object::Section::Options::Weak if section.weak
        current_section = Object::Section.new section.name, section.offset, options
        object.sections << current_section
      end

      statement.symbol.try do |label|
        all_defintions[label]?.try do |previous|
          raise "Duplicate symbol '#{label}' in #{unit.name || "???"} at line #{statement.line}. Previously defined at line #{previous.line}"
        end
        all_defintions[label] = statement
        current_section.definitions[label] = Object::Section::Symbol.new text.size, statement.exported
      end

      statement.instruction.try do |instruction|
        case memo = instruction.memo.downcase
        when "add", "nand"
          reg_a = instruction.parameters[0].as AST::Register
          reg_b = instruction.parameters[1].as AST::Register
          reg_c = instruction.parameters[2].as AST::Register
          text << Instruction.new(ISA.parse(memo), reg_a.index.to_u16, reg_b.index.to_u16, reg_c.index.to_u16).encode
        when "addi", "sw", "lw"
          reg_a = instruction.parameters[0].as AST::Register
          reg_b = instruction.parameters[1].as AST::Register
          immediate = instruction.parameters[2].as AST::Immediate
          offset = assemble_immediate current_section, text.size, immediate, Object::Section::Reference::Kind::Imm
          text << Instruction.new(ISA.parse(memo), reg_a.index.to_u16, reg_b.index.to_u16, immediate: offset).encode
        when "beq"
          reg_a = instruction.parameters[0].as AST::Register
          reg_b = instruction.parameters[1].as AST::Register
          immediate = instruction.parameters[2].as AST::Immediate
          offset = assemble_immediate current_section, text.size, immediate, Object::Section::Reference::Kind::Beq
          text << Instruction.new(ISA::Beq, reg_a.index.to_u16, reg_b.index.to_u16, immediate: offset).encode
        when "lui"
          reg_a = instruction.parameters[0].as AST::Register
          immediate = instruction.parameters[1].as AST::Immediate
          offset = assemble_immediate current_section, text.size, immediate, Object::Section::Reference::Kind::Lui
          text << Instruction.new(ISA::Lui, reg_a.index.to_u16, immediate: offset).encode
        when "jalr"
          reg_a = instruction.parameters[0].as AST::Register
          reg_b = instruction.parameters[1].as AST::Register
          text << Instruction.new(ISA::Jalr, reg_a.index.to_u16, reg_b.index.to_u16).encode
        when "nop"
          text << Instruction.new(ISA::Add).encode
        when "lli"
          reg_a = instruction.parameters[0].as AST::Register
          immediate = instruction.parameters[1].as AST::Immediate
          offset = assemble_immediate current_section, text.size, immediate, Object::Section::Reference::Kind::Lli
          text << Instruction.new(ISA::Addi, reg_a.index.to_u16, reg_a.index.to_u16, immediate: offset & 0x3fu16).encode
        when "movi"
          reg_a = instruction.parameters[0].as AST::Register
          immediate = instruction.parameters[1].as AST::Immediate
          offset = assemble_immediate current_section, text.size, immediate, Object::Section::Reference::Kind::Lui
          text << Instruction.new(ISA::Lui, reg_a.index.to_u16, immediate: offset).encode
          offset = assemble_immediate current_section, text.size, immediate, Object::Section::Reference::Kind::Lli
          text << Instruction.new(ISA::Addi, reg_a.index.to_u16, reg_a.index.to_u16, immediate: offset).encode
        when "halt"
          text << Instruction.new(ISA::Jalr, immediate: 1u16).encode
        when ".word"
          immediate = instruction.parameters[0].as AST::Immediate
          text << assemble_immediate current_section, text.size, immediate, Object::Section::Reference::Kind::Data
        when ".ascii"
          string = instruction.parameters[0].as AST::Text
          string.text.to_slice.each { |byte| text << byte.to_u16 }
        when "function"
          stack = instruction.parameters[0].as AST::Register
          call = instruction.parameters[1].as AST::Register
          text << Instruction.new(ISA::Sw, reg_a: call.index.to_u16, reg_b: stack.index.to_u16, immediate: 1u16).encode
        when "return"
          stack = instruction.parameters[0].as AST::Register
          ret = instruction.parameters[1].as AST::Register
          call = instruction.parameters[2].as AST::Register
          text << Instruction.new(ISA::Lw, reg_a: call.index.to_u16, reg_b: stack.index.to_u16, immediate: 1u16).encode
          text << Instruction.new(ISA::Sw, reg_a: ret.index.to_u16, reg_b: stack.index.to_u16, immediate: 1u16).encode
          text << Instruction.new(ISA::Jalr, reg_a: 0u16, reg_b: call.index.to_u16, immediate: 0u16).encode
        when "call"
          target = instruction.parameters[0].as AST::Immediate
          stack = instruction.parameters[1].as AST::Register
          call = instruction.parameters[-1].as AST::Register
          regs = instruction.parameters[2..(-2)].map &.as AST::Register
          regs.each_with_index do |reg, index|
            text << Instruction.new(ISA::Sw, reg_a: reg.index.to_u16, reg_b: stack.index.to_u16, immediate: index == 0 ? 0u16 : MAX_IMMEDIATE - index).encode
          end
          text << Instruction.new(ISA::Addi, reg_a: stack.index.to_u16, reg_b: stack.index.to_u16, immediate: MAX_IMMEDIATE - (regs.size)).encode
          offset = assemble_immediate current_section, text.size.to_u16, target, Object::Section::Reference::Kind::Lui
          text << Instruction.new(ISA::Lui, reg_a: call.index.to_u16, immediate: offset >> 6).encode
          offset = assemble_immediate current_section, text.size, target, Object::Section::Reference::Kind::Lli
          text << Instruction.new(ISA::Addi, reg_a: call.index.to_u16, reg_b: call.index.to_u16, immediate: offset).encode
          text << Instruction.new(ISA::Jalr, reg_a: call.index.to_u16, reg_b: call.index.to_u16, immediate: 0u16).encode
          text << Instruction.new(ISA::Lw, reg_a: call.index.to_u16, reg_b: stack.index.to_u16, immediate: 1u16).encode
          regs.each_with_index do |reg, index|
            text << Instruction.new(ISA::Lw, reg_a: reg.index.to_u16, reg_b: stack.index.to_u16, immediate: index.to_u16 + 2).encode
          end
          text << Instruction.new(ISA::Addi, reg_a: stack.index.to_u16, reg_b: stack.index.to_u16, immediate: regs.size.to_u16 + 1).encode
        else raise "Unknown statement memo '#{memo}' in #{unit.name || "???"} at line #{statement.line}."
        end
      end
    end
    current_section.text = Slice.new text.size do |i|
      text[i]
    end
    object
  end
end
