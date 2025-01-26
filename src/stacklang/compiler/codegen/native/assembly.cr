alias Kind = RiSC16::Object::Section::Reference::Kind
alias ISA = RiSC16::ISA
alias Instruction = RiSC16::Instruction

# Helper functions for generating the actual RiSC16 instructions
class Stacklang::Native::Generator
  def overflow_immediate_offset?(value)
    return true if value.is_a? String
    value > 0x3F || value < -0x40
  end

  def load_immediate(into : Register, imm : Int32 | String, offset = 0)
    case imm
    in String then movi into, imm, offset
    in Int32
      if !overflow_immediate_offset? imm
        addi into, Register::R0, imm
      elsif imm.bits(0..7) == 0
        lui into, imm
      else
        movi into, imm
      end
    end
  end

  def add(a : Register, b : Register, c : Register)
    @text << Instruction.new(ISA::Add, a.value, b.value, c.value).encode
  end

  def nand(a : Register, b : Register, c : Register)
    @text << Instruction.new(ISA::Nand, a.value, b.value, c.value).encode
  end

  def lui(a : Register, imm : Int32 | String, offset = 0)
    @text << Instruction.new(ISA::Lui, a.value, immediate: assemble_immediate imm, Kind::Lui, offset).encode
  end

  def lli(a : Register, imm : Int32 | String, offset = 0)
    @text << Instruction.new(ISA::Addi, a.value, a.value, immediate: assemble_immediate imm, Kind::Lli, offset).encode
  end

  def movi(a : Register, imm : Int32 | String, offset = 0)
    lui a, imm, offset
    lli a, imm, offset
  end

  def addi(a : Register, b : Register, imm : Int32 | String)
    @text << Instruction.new(ISA::Addi, a.value, b.value, immediate: assemble_immediate imm, Kind::Imm).encode
  end

  def sw(a : Register, b : Register, imm : Int32 | String)
    @text << Instruction.new(ISA::Sw, a.value, b.value, immediate: assemble_immediate imm, Kind::Imm).encode
  end

  def lw(a : Register, b : Register, imm : Int32 | String)
    @text << Instruction.new(ISA::Lw, a.value, b.value, immediate: assemble_immediate imm, Kind::Imm).encode
  end

  def jalr(a : Register, b : Register)
    @text << Instruction.new(ISA::Jalr, a.value, b.value).encode
  end

  def beq(a : Register, b : Register, imm : Int32 | String)
    @text << Instruction.new(ISA::Beq, a.value, b.value, immediate: assemble_immediate imm, Kind::Beq).encode
  end

  # Helper function for assembling immediate value.
  # It provide a value for the immediate, or store the reference for linking if the value is a symbol.
  def assemble_immediate(immediate : Int32 | String, kind : Kind, offset = 0)
    if immediate.is_a? String
      references = @section.references[immediate] ||= [] of RiSC16::Object::Section::Reference
      references << RiSC16::Object::Section::Reference.new @text.size.to_u16, offset, kind
      0u16
    else
      immediate = immediate.as?(Int32).not_nil!
      bits = case kind
             when .imm?, .beq? then 7
             else                   16
             end
      value = (immediate < 0 ? (2 ** bits) + immediate.bits(0...(bits - 1)) : immediate).to_u16
      value = value >> 6 if kind.lui?
      value = value & 0x3fu16 if kind.lli?
      value
    end
  end
end
