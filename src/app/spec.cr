require "./risc16"
require "ini"
require "log"

class RiSC16::Spec
  @properties : Hash(String, Hash(String, String))
  @sections : Array(Section)?
  @segments : Array(Segment)?
  @macros : Hash(String, String)

  class Section
    property name : String
    property base_address : UInt32?
    property max_size : UInt32?
    property options : Object::Section::Options

    def initialize(@name, @base_address, @max_size, @options = Object::Section::Options::None)
    end
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
      property read : Bool
      property write : Bool

      def initialize(properties)
        super
        case property = properties["read"]?
        when "true", nil then @read = true
        when "false"     then @read = false
        else                  raise "Bad value for segment properties write: '#{property}'"
        end
        case property = properties["write"]?
        when "true", nil then @write = true
        when "false"     then @write = false
        else                  raise "Bad value for segment properties write: '#{property}'"
        end
      end
    end

    class IO < Segment
      property tty : Bool
      property source : String?
      property sink : String?

      def initialize(properties)
        properties["size"] = "1"
        super
        case is_tty = properties["tty"]?
        when "true"       then @tty = true
        when "false", nil then @tty = false
        else                   raise "Bad value for segment properties tty: '#{is_tty}'"
        end
        @source = properties["source"]?
        @sink = properties["sink"]?
        raise "At least one of source or sink must be provided for no-tty io segment" if @source.nil? && @sink.nil? && !@tty
      end
    end

    class Rom < Segment
      property source : String

      def initialize(properties)
        @source = properties["source"]
        super
      end
    end

    property start : UInt16
    property size : UInt16
    property name : String?

    def initialize(properties)
      @size = properties["size"].to_u16 prefix: true
      @start = properties["start"].to_u16 prefix: true
      @name = properties["name"]?
    end

    def self.build(properties)
      case Kind.parse properties["kind"]
      when .ram?     then Ram.new properties
      when .rom?     then Rom.new properties
      when .io?      then IO.new properties
      when .default? then Default.new properties
      end
    end
  end

  getter path
  
  def initialize(@properties, @macros, @path : String)
    @properties.transform_values! &.transform_values do |value|
      if value.starts_with? '$'
        @macros[value.lchop]? || value
      else
        value
      end
    end

    segments.sort_by(&.start).reduce(0) do |address, segment|
      raise "Hardware memory segment '#{segment.name}' overflow previous segment" if segment.start < address
      raise "Hardware memory segment '#{segment.name}' overflow maximum address" if segment.start.to_i + segment.size.to_i - 1 > UInt16::MAX
      segment.start.to_i + segment.size
    end
  end

  def self.open(io, macros, path)
    self.new INI.parse(io), macros, path
  end

  def segments
    @segments ||= @properties.keys.compact_map do |key|
      key.lchop?("hardware.segment.").try do |segment_name|
        @properties[key]["name"] = segment_name
        Segment.build @properties[key]
      end
    end
  end

  def sections
    @sections ||= @properties.keys.compact_map do |key|
      key.lchop?("linker.section.").try do |section_name|
        Section.new section_name, @properties[key]["start"]?.try &.to_u32(prefix: true), @properties[key]["size"]?.try &.to_u32(prefix: true)
      end
    end
  end
end
