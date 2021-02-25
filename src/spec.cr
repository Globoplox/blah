require "./risc16"
require "ini"

class RiSC16::Spec
  @properties : Hash(String, Hash(String, String))
  @io : Array(IO)? = nil

  def initialize(@properties) end

  def self.open(filename)
    File.open filename do |io|
      self.new INI.parse io
    end
  end

  def self.default
    self.new({} of String => Hash(String, String))
  end

  DEFAULT_RAM_START = 0u16 
  def ram_start
    @properties["general"]?.try &.["ram.start"]?. try &.to_u16 || DEFAULT_RAM_START
  end

  def ram_size
    @properties["general"]?.try &.["ram.size"]?. try &.to_u16 || MAX_MEMORY_SIZE - DEFAULT_RAM_START - io.size
  end

  def stack_start
    @properties["general"]?.try &.["stack.start"]?. try &.to_u16 || DEFAULT_RAM_START + (ram_size - 1)
  end

  def io_start
    @properties["general"]?.try &.["io.start"]?. try &.to_u16 ||  DEFAULT_RAM_START + ram_size
  end

  def io_size
    io.size.to_u16
  end

  record IO, index : Word, name : String, input : String, output : String
  def io
    @io ||= @properties.keys.compact_map do |key|
      key.lchop?("io.").try do |io_name|
        index = @properties[key]["index"].to_u16
        input = @properties[key]["output"]
        output = @properties[key]["input"]
        IO.new index, io_name, input, output
      end
    end
  end
end
