# Represent a relocatable object.
# It can be linked into other objects or into a binary. See `RiSC16::Assembler::Linker`.
class RiSC16::Object
  # Optional name used to indicate the origin source of an object file, for helping humans.
  property name : String? 

  # The array of sections, that is, continuous piece of data, declaring and referencing symbols.
  property sections : Array(Section) = [] of Section

  # Indicate if the object is ready for linking or not.
  # An object file incated as merged should:
  # have all the sections it contains have a fixed, relative to 0, absolute address.
  property merged : Bool

  def initialize(@name = nil)
    @merged = false
  end

  # return true is this object define a start symbol in a section.
  # This is useful to check if this is supposed to be executable.
  def has_start?
    sections.any? do |section|
      section.definitions["start"]?.try &.exported
    end
  end

  # A section is a continuous block of code with it's symbols definitions and references.
  #
  # The block of code is not usable as is, it require to be linked to solve the references.
  # All the address are relative to the start of the block of code
  # It has an optional offset within a namespace where it expect to be loaded.
  # When ready for merging, a section should have an absolute, expected loading address (relative to address 0).
  # This allows the linker to quickly adjust the symbols addresses given the real loading address.
  class	Section
    property name : String
    property offset : Int32? = nil
    property absolute : Int32? = nil
    property text : Slice(UInt16) = Slice(UInt16).empty
    property definitions : Hash(String, Symbol) = {} of String => Symbol
    property references : Hash(String, Array(Reference)) = {} of String => Array(Reference)
    property options : Options
    
    @[Flags]
    enum Options
      Weak # The section fragments might be ignored in static binary if there are no references to any of its exported symbols.
           # This option can differ from section fragment to section fragment. It is usefull only when building a static binary.
    end

    def initialize(@name, @offset = nil, @options = Options::None) end

    # Represent a symbol defined by a section.
    # It can be static to the section or global depending on `#exported`.
    # The `#address` is relative to the block of code of the section it belongs to.
    class Symbol
      # NOTE the address is sometimes used to store macros values from the specification. file `RiSC16::Spec`. This is why it must allows negative values.
      property address : Int32
      property exported	: Bool
      def initialize(@address, @exported) end
    end

    # Represent a reference to a symbol.
    # The `#address` is the offset within the block of code of the section where the reference is stored.
    # The `#offset` is an value to add to the reference symbol value before writing it within the block of code.
    # the `#kind` control how the referenced value should be written and which restriction must be applied.
    class Reference
      property address : UInt16
      property offset : Int32
      property kind : Kind
      enum Kind
        # Value must be converted to a 7 bit complement form signed integer, to write in the 7 lsb of the `Reference#offset`'th word of `Section#text`.  
	Imm

        # Value must be converted to a 16 bit complement form signed integer, to write the 10 msb of in the 10 lsb of the `Reference#offset`'th word of `Section#text`.
        Lui

        # Value must be converted to a 16 bit complement form signed integer, to write the 6 lsb of in the 7 lsb of the `Reference#offset`'th word of `Section#text`.
        Lli

        # Value must be converted to a 16 bit complement form signed integer, to write in the `Reference#offset`'th word of `Section#text`.
	Data

        # Value must be made relative to reference addres, then converted to a 7 bit complement form signed integer,
        # to write in the 7 lsb of the `Reference#offset`'th word of `Section#text`.
        Beq #
      end
      def initialize(@address, @offset, @kind) end
    end
  end

  ENDIAN = IO::ByteFormat::BigEndian 

  # Serialize this object to the given *io*.
  def to_io(io, endian = ENDIAN)
    (@merged ? 1u8 : 0u8).to_io io, endian
    @sections.size.to_io io, endian
    @sections.each do |section|
      section.name.to_slice.size.to_io io, endian
      io.write section.name.to_slice
      section.options.value.to_io io, endian
      (section.offset.nil? ? 0u8 : 1u8).to_io io, endian
      (section.offset || 0).to_io io, endian
      (section.absolute.nil? ? 0u8 : 1u8).to_io io, endian
      (section.absolute || 0).to_io io, endian
      section.definitions.size.to_io io, endian
      section.definitions.each do |name, definition|
        name.to_slice.size.to_io io, endian
        io.write name.to_slice
        definition.address.to_io io, endian
        (definition.exported ? 1u8 : 0u8).to_io io, endian
      end
      section.references.size.to_io io, endian
      section.references.each do |name, references|
        name.to_slice.size.to_io io, endian
        io.write name.to_slice
        references.size.to_io io, endian
        references.each do |reference|
          reference.address.to_io io, endian
          reference.offset.to_io io, endian
          reference.kind.to_u8.to_io io, endian
        end
      end
      section.text.size.to_io io, endian
      section.text.each &.to_io io, endian
    end
  end

  # Build an object from given *io*.
  def self.from_io(io, name = nil, endian = ENDIAN)
    object = self.new(name)
    object.merged = UInt8.from_io(io, endian) != 0
    (Int32.from_io io, endian).times do
      section = Section.new io.read_string (Int32.from_io io, endian)
      object.sections << section
      section.options = Section::Options.from_value Int32.from_io io, endian
      has_offset = io.read_byte
      section.offset = Int32.from_io io, endian
      section.offset = nil if has_offset == 0
      has_absolute = io.read_byte
      section.absolute = Int32.from_io io, endian
      section.absolute = nil if has_absolute == 0
      (Int32.from_io io, endian).times do
        name = io.read_string (Int32.from_io io, endian)
        address = Int32.from_io io, endian
        exported = io.read_byte
        section.definitions[name] = Section::Symbol.new address, exported != 0
      end
      (Int32.from_io io, endian).times do
        name = io.read_string (Int32.from_io io, endian)
        references = [] of Section::Reference
        (Int32.from_io io, endian).times do
          address = UInt16.from_io io, endian
          offset = Int32.from_io io, endian
          kind = Section::Reference::Kind.from_value io.read_byte.not_nil!
          references << Section::Reference.new address, offset, kind
        end
        section.references[name] = references
      end
      text_size = Int32.from_io io, endian
      section.text = Slice(UInt16).new text_size
      (0...text_size).each do |index|
        section.text[index] = UInt16.from_io io, endian
      end
    end
    object
  end
end
