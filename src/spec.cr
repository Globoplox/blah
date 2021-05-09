require "./risc16"
require "ini"

class RiSC16::Spec
  @properties : Hash(String, Hash(String, String))
  @io : Array(Peripheral)? = nil
  # @sections : Array(Section)? = nil
  @macros : Hash(String, String)

  def initialize(@properties, @macros) end

  def self.open(filename, macros)
    File.open filename do |io|
      self.new INI.parse(io), macros
    end
  end

  def self.default
    self.new({} of String => Hash(String, String), {} of String => String)
  end

  def solve(value)
    if value.starts_with? '$'
      @macros[value.lchop]? || value
    else
      value
    end
  end

  # class Section
  #   property name : String
  #   property base_address : Word
  #   property max_size : UInt32? = nil
  #   def initialize(@name, @base_address, @max_size = nil) end
  # end

  DEFAULT_SECTION_NAME = "RAM"
  DEFAULT_RAM_START = 0u16
  
  def ram_start
    @properties["general"]?.try &.["ram.start"]?. try &.to_u16(prefix: true) || DEFAULT_RAM_START
  end

  def ram_size
    @properties["general"]?.try &.["ram.size"]?. try &.to_u16(prefix: true) || MAX_MEMORY_SIZE - DEFAULT_RAM_START - io.size
  end

  def stack_start
    @properties["general"]?.try &.["stack.start"]?. try &.to_u16(prefix: true) || DEFAULT_RAM_START + (ram_size - 1)
  end

  def io_start # 0 if irrelevant because ram eat all the space available
    @properties["general"]?.try &.["io.start"]?. try &.to_u16(prefix: true) || (ram_size == MAX_MEMORY_SIZE ? 0u16 : DEFAULT_RAM_START + ram_size)
  end

  def io_size : Word
    io.size.to_u16
  end

  enum IOKind
    TTY
    ROM
  end
  
  abstract class Peripheral
    abstract def index : UInt16
    abstract def name : String
  end

  class Peripheral::TTY < Peripheral
    property index : UInt16
    property name : String
    def initialize(@index, @name) end
  end
  
  class Peripheral::ROM < Peripheral
    property index : UInt16
    property name : String
    property source : String
    def initialize(@index, @name, @source) end
  end
  
  def io
    @io ||= @properties.keys.compact_map do |key|
      key.lchop?("io.").try do |io_name|
        case @properties[key]["type"]?
        when "tty" then Peripheral::TTY.new @properties[key]["index"].to_u16, io_name
        when "rom" then Peripheral::ROM.new @properties[key]["index"].to_u16, io_name, solve @properties[key]["source"]
        when nil then raise "Bad IO missing kind for '#{key}'."
        else raise "Bad IO peripheral kind for '#{key}': '#{@properties[key]["type"]}'."
        end
      end
    end
  end

  # def sections
  #   @sections ||= (@properties.keys.compact_map do |key|
  #     key.lchop?("section.").try do |section_name|
  #       Section.new section_name, @properties[key]["start"]?.to_u16, @properties[key]["size"]?.try &.to_u16
  #     end
  #   end + Section.new DEFAULT_SECTIO_NAME, ram_start, ram_size)
  # end
end
