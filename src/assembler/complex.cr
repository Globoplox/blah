require "./assembler"

class RiSC16::Assembler::Complex
  
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
               ((2 ** bits) + result.bits(0...(bits - 1))).to_u16
             else
               result.to_u16
             end
    raise "Immediate result #{result} overflow from store size of #{bits} bits" if result & ~0 << bits != 0
    result
  end
      
end
