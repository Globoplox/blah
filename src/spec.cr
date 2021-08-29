require "./risc16"
require "ini"

class RiSC16::Spec
  @properties : Hash(String, Hash(String, String))
  @sections : Array(Section)? = nil
  @segments : Array(Segments)? = nil
  @macros : Hash(String, String)

  class Section
    property name : String
    property base_address : UInt32? = nil
    property max_size : UInt32? = nil
    def initialize(@name, @base_address, @max_size) end
  end

  abstract class Segment

    enum Kind
      RAM
      ROM
      IO
      DEFAULT
    end

    class Ram < Segment
    end

    class Default < Segment
      property read : Boolean
      property write : Boolean

      def initialize(properties)
        super
        case property = properties["read"]?
        when "true", nil @read = true
        when "false" @read = false
        else raise "Bad value for segment properties write: '#{property}'"
        end
        case property = properties["write"]?
        when "true", nil @write = true
        when "false" @write = false
        else raise "Bad value for segment properties write: '#{property}'"
        end
      end
    end

    abstract class IO < Segment
      property tty : Boolean
      property source : String?

      def initialize(properties)
        properties["size"] = "1"
        super
        case is_tty = properties["tty"]?
        when "true" @tty = true
        when "false", nil @tty = false
        else raise "Bad value for segment properties tty: '#{is_tty}'"
        end
        @source = properties["source"]?
        raise "Source must be provided for no-tty io segment" if @source.nil? && !@tty              
      end
    end
    
    abstract class Rom < Segment
      property source : String

      def initialize(properties)
        @source = properties["source"]
      end
    end

    property start : UInt16
    property size : UInt16
    property name : String?
    
    def initialize(properties)
      @size = properties["size"].to_u16
      @start = properties["start"].to_u16
      @name = properties["name"]?
    end

    def self.new(properties)
      case Kind.parse properties["kind"]
      when .ram? then Ram.new properties
      when .rom? then Rom.new properties
      when .io? then IO.new properties
      when .default? then Default.new properties
    end
  end
  
  def initialize(@properties, @macros)
    @properties.transform_values do |value|
      if value.starts_with? '$'
        @macros[value.lchop]? || value
      else
        value
      end
    end

    @segments.sort_by(&.start).reduce(0u16)? do |address, segment|
      raise "Hardware memory segment '#{segment.name}' overflow previous segment" if segment.start < address
      segment.start + segment.size
    end
  end

  def self.open(filename, macros)
    File.open filename do |io|
      self.new INI.parse(io), macros
    end
  end

  def self.default
    self.new(
      {
        "hardware.segment.ram" => {"kind" => "ram", "start" => 0x0.to_s, "size" => 0xfffe.to_s},
        "hardware.segment.tty" => {"kind" => "io", "tty" => "true", "start" => 0xffff.to_s},
        "linker.section.text" => { "start" => "0" }
      }, {} of String => String)
  end

  def segments
    @segments ||= @properties.keys.compact_map do |key|
      key.lchop?("hardware.segment.").try do |segment_name|
        @properties[key]["name"] = segment_name
        Segment.new @properties[key]
      end
    end
  end
  
  def sections
    @sections ||= @properties.keys.compact_map do |key|
      key.lchop?("linker.section.").try do |section_name|
        Section.new section_name, @properties[key]["start"]?.try &.to_u32, @properties[key]["size"]?.try &.to_u32
      end
    end
  end
end
