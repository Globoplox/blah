require "./assembler"

module RiSC16::Assembler

  # Parse an immediate specification.
  def self.parse_immediate(raw : String): Complex
    immediate = /^(?<label>:[A-Z_][A-Z_0-9]*)?((?<mod>\+|-)?(?<offset>(0x|0b|(0))?[A-F_0-9]+))?$/i.match raw
    raise "Bad immediate '#{raw}'" if immediate.nil?
    label = immediate["label"]?.try &.lchop ':'
    offset = immediate["offset"]?
    raise "Invalid immediate '#{raw}'" unless label || offset
    offset = offset.try &.to_i32(underscore: true, prefix: true) || 0
    Complex.new label, offset, immediate["mod"]? == "-" && offset != 0
  end
  
  # Parse RRR type parameters.
  def self.parse_rrr(params)
    arr = params.split /\s+/, remove_empty: true
    raise "Unexpected rrr parameters amount: found #{arr.size}, expected 3" unless arr.size == 3
    arr = arr.map do |register| register.lchop?('r') || register end
    { arr[0].to_u16, arr[1].to_u16, arr[2].to_u16 }
  end
  
  # Parse RRI type parameters.
  def self.parse_rri(params, no_i = false)
    arr = params.split /\s+/, remove_empty: true
    raise "Unexpected rri type parameters amount: found #{arr.size}, expected #{no_i ? 2 : 3}" unless arr.size == 3 || (no_i && arr.size == 2)
    arr = arr.map do |register| register.lchop?('r') || register end
    { (arr[0].lchop?('r') || arr[0]).to_u16, (arr[1].lchop?('r') || arr[1]).to_u16, no_i ? Complex.new(nil, 0, false) : parse_immediate arr[2] }
  end
  
  # Parse RT type parameters.
  def self.parse_ri(params)
    arr = params.split /\s+/, remove_empty: true
    raise "Unexpected ri type parameters amount: found #{arr.size}, expected 2" unless arr.size == 2
    arr = arr.map do |register| register.lchop?('r') || register end
    { (arr[0].lchop?('r') || arr[0]).to_u16, parse_immediate arr[1] }
  end
end
