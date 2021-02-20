# https://user.eng.umd.edu/~blj/RiSC/RiSC-isa.pdf
# DONE # Indexing store expected memory location in LOC
# DONE # More complex immediate: label+-offset
# DONE: VM can do math
# Debugging: decoding, desassembling, assembler hints
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
# Process: in case of fault: switch ram for rom microcode and pc to special microcode-pc (init pc depending on fault)
#                            

# Now we have a "runtime" for the proc maybe we can make a micro kernel: system lib, syscall, runtime linking and loading of program with a more complex file structure.
# # Runtime linking would: loading a program and replacing external ref with those of a previously laoded library.
# Program could be given an indicative memory section to sray in (wont be enforced).
# Subdivision of ram in io, firmware (interrupts), kernel & syscall, and programsLlibs area. (split userland in program, sinlib, stack, and dyn mem alloc)
#  kernal keep a table of libs, and a table of process (stack). 
# Program could ask for a ram amount and a priority. Syscall would allow for kernel code to decide, with priority of which program to resume next.
# # Nothing would be safe without memory proptection but still fun.
# # The loaded code need to be aware that iy has a dynamic base_address and should probably keep it in a register.
# Finally we would want a minimalistic stack based language.
# Tool for editing, debuging, desassembling.
module RiSC16
  VERSION = "0.1.0"
  
  alias Word = UInt16

  # Register 0 is always zero. Write are discarded.
  REGISTER_COUNT = 8
  MAX_MEMORY_SIZE = UInt16::MAX
  
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
  # Does not perform sanity checks yet at construction.
  class Instruction
    getter op : ISA
    getter reg_a : UInt16
    getter reg_b : UInt16
    getter reg_c : UInt16
    getter immediate : UInt16
    
    def initialize(@op, @reg_a = 0_u16, @reg_b = 0_u16, @reg_c = 0_u16, @immediate = 0_u16)
    end

    def encode
      instruction = @op.value.to_u16 << 13
      case @op
      when ISA::Add, ISA::Nand
        instruction |= ((@reg_a & 0b111) << 10) | ((@reg_b & 0b111) << 7) | @reg_c & 0b111
      when ISA::Addi, ISA::Sw, ISA::Lw, ISA::Beq, ISA::Jalr
        raise "Immediate overflow #{@immediate.to_s base: 16} for #{@op}" if @immediate > ~(~0 << 7)
        instruction |= ((@reg_a & 0b111) << 10) | ((@reg_b & 0b111) << 7) | (@immediate & 0b1111111)
      when ISA::Lui
        raise "Immediate overflow #{@immediate.to_s base: 16} for #{@op}" if @immediate > ~(~0 << 10)
        instruction |= ((@reg_a & 0b111) << 10) | (@immediate & 0b_11_1111_1111)
      end
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
end
