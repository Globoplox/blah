class Stacklang::Function
  def add(a : Registers, b : Registers, c : Registers)
    @text << Instruction.new(ISA::Add, a.value, b.value, c.value).encode
  end

  def nand(a : Registers, b : Registers, c : Registers)
    @text << Instruction.new(ISA::Nand, a.value, b.value, c.value).encode
  end

  def lui(a : Registers, imm : Int32 | String | Memory)
    @text << Instruction.new(ISA::Lui, a.value, immediate: assemble_immediate imm, Kind::Lui).encode
  end

  def lli(a : Registers, imm : Int32 | String | Memory)
    @text << Instruction.new(ISA::Addi, a.value, a.value, immediate: assemble_immediate imm, Kind::Lli).encode
  end

  # Do nothing but predict the size a movi macro instruction will take in instructions
  def predict_movi(a : Registers, imm : Int32 | String | Memory)
    imm = imm.value if imm.is_a? Memory
    if imm.is_a? Int32 && imm <= 0x3f
      1u16
    else
      2u16
    end
  end

  def movi(a : Registers, imm : Int32 | String | Memory)
    imm = imm.value if imm.is_a? Memory
    if imm.is_a? Int32 && imm <= 0x3f
      addi a, Registers::R0, imm & 0x3f
    else
      lui a, imm
      lli a, imm
    end
  end

  def addi(a : Registers, b : Registers, imm : Int32 | String | Memory)
    @text << Instruction.new(ISA::Addi, a.value, b.value, immediate: assemble_immediate imm, Kind::Imm).encode
  end

  def sw(a : Registers, b : Registers, imm : Int32 | String | Memory)
    @text << Instruction.new(ISA::Sw, a.value, b.value, immediate: assemble_immediate imm, Kind::Imm).encode
  end

  def lw(a : Registers, b : Registers, imm : Int32 | String | Memory)
    @text << Instruction.new(ISA::Lw, a.value, b.value, immediate: assemble_immediate imm, Kind::Imm).encode
  end

  def jalr(a : Registers, b : Registers)
    @text << Instruction.new(ISA::Jalr, a.value, b.value).encode
  end

  def beq(a : Registers, b : Registers, imm : Int32 | String | Memory)
    @text << Instruction.new(ISA::Beq, a.value, b.value, immediate: assemble_immediate imm, Kind::Beq).encode
  end

  # Helper function for assembling immediate value.
  # It provide a value for the immediate, or store the reference for linking if the value is a symbol.
  def assemble_immediate(immediate : Int32 | String | Memory, kind : Kind)
    if immediate.is_a? String
      references = @section.references[immediate] ||= [] of Object::Section::Reference
      references << Object::Section::Reference.new @text.size.to_u16, 0, kind
      0u16
    else
      immediate = (immediate.as?(Int32) || immediate.as?(Memory).try(&.value)).not_nil!
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
