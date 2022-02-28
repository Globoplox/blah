require "../risc16"
require "./object"

module RiSC16::Linker
  extend self

  ENDIAN = IO::ByteFormat::BigEndian
  
  def symbols_from_spec(spec)
    predefined_symbols = {} of String => Object::Section::Symbol
    spec.segments.each do |segment|
      absolute = segment.start.to_i32
      if segment.is_a? RiSC16::Spec::Segment::IO
        predefined_symbols["__io_#{segment.name}"] = Object::Section::Symbol.new absolute, false
      else
        predefined_symbols["__segment_#{segment.name}"] = Object::Section::Symbol.new absolute, false
      end
    end
    spec.sections.each do |section|
      section.base_address.try do |address|
        predefined_symbols["__section_#{section.name}"] = Object::Section::Symbol.new address.to_i32, false
      end
    end
    predefined_symbols
  end

  # Link several objects into a single object, with all blocks offset set.
  def merge(spec : Spec, objects : Array(RiSC16::Object)) : RiSC16::Object
    start = 0
    predefined_section_size = {} of String => UInt32
    predefined_section_address = {} of String => UInt32
    spec.sections.each do |section|
      max = section.max_size
      base = section.base_address
      predefined_section_size[section.name] = max if max
      predefined_section_address[section.name] = base if base
    end

    globals = symbols_from_spec(spec)

    # check for conflict between exported symbols
    objects.each &.sections.each &.definitions.each do |(name, symbol)|
      next unless symbol.exported
      raise "duplicate global symbol #{name}" if globals[name]?
      globals[name] = symbol
    end

    # Set all the texts, symbols and references address
    # by ordering all "sections", then each fragment of this section
    # and adding the size of each. Raise when constraint is not possible and jump directly to offset when their are gaps
    # TODO: dump layout in case of overflow
    text_size = objects.flat_map(&.sections).group_by(&.name).to_a.sort_by do |(name, sections)|
      predefined_section_address[name]? || Int32::MAX
    end.reduce(start) do |absolute, (name, sections)|
      base = predefined_section_address[name]?.try &.to_i32 || absolute
      raise "Section #{name} cannot overwrite at offset #{base}, there are already data up to #{absolute}" if base < absolute
      sections.sort_by { |section| section.offset || Int32::MAX }.reduce(base) do |absolute, section|
        if (section.offset || Int32::MAX) < absolute
          raise "Block offset conflict in section #{name}, cannot overwrite at offset #{section.offset}, there are already data up to #{absolute}"
        end
        section.offset ||= absolute
        section.definitions.values.each do |symbol|
          symbol.address = symbol.address + section.offset.not_nil!
        end
        section.references.values.each &.each do |ref|
          ref.address = (ref.address.to_i32 + section.offset.not_nil!).to_u16
        end
        section.offset.not_nil! + section.text.size
      end.tap do |at_end|
        size = at_end - base
        max = predefined_section_size[name]? || Int32::MAX
        raise "Section #{name} of size #{size} overflow maximum size constraint #{max}" if size > max
      end
    end

    RiSC16::Object.new.tap do |object|
      objects.each &.sections.each do |section|
        object.sections << section
      end
      object.merged = true
    end
  end

  # Static link binary
  def static_link(spec, object, io, start : Int32 = 0)
    object = merge(spec, [object]) if object.merged == false
    globals = symbols_from_spec(spec)

    if start != 0 
      object.sections.each do |section|
        section.definitions.values.each do |symbol|
          symbol.address += start
        end
        section.references.values.each &.each do |ref|
          ref.address = (ref.address.to_i32 + start).to_u16
        end
        section.offset = section.offset.not_nil! + start
      end
    end

    object.sections.each &.definitions.each do |(name, symbol)|
      next unless symbol.exported
      globals[name] = symbol
    end

    max = object.sections.max_by do |section|
      section.offset.not_nil! + section.text.size
    end
    text_size = max.offset.not_nil! + max.text.size

    binary = Slice(UInt16).new text_size
    
    # perform references replacement
    # write to file
    object.sections.each do |section|
      symbols = globals.merge section.definitions.reject { |name, symbol| symbol.exported } 
      section.text.copy_to binary[(section.offset.not_nil!)...(section.offset.not_nil! + section.text.size)]
      section.references.each do |name, references|
        symbol = symbols[name]? || raise "Undefined reference to symbol '#{name}' in section '#{section.name}'"
        references.each do |reference|
          value = symbol.address + reference.offset
          case reference.kind
            in Object::Section::Reference::Kind::Data
              if value > 0b1111_1111_1111_1111 || value < - 0b1111_1111_1111_1111
                raise "Reference to #{name} = #{value} overflow from allowed 16 bits for symbol of type #{reference.kind}"
              end
              binary[reference.address] = (value < 0 ? (2 ** 16) + value.bits(0...(16 - 1)) : value).to_u16
            in Object::Section::Reference::Kind::Imm
              if value > 0b0011_1111 || value < - 0b0111_1111
                raise "Reference to #{name} = #{value} overflow from allowed 7 bits for symbol of type #{reference.kind}"
              end
              binary[reference.address] = binary[reference.address] & ~0b0111_1111 | (value < 0 ? (2 ** 7) + value.bits(0...(7 - 1)) : value).to_u16
            in Object::Section::Reference::Kind::Lui
              if value > 0b1111_1111_1111_1111 || value < - 0b1111_1111_1111_1111
                raise "Reference to #{name} = #{value} overflow from allowed 16 bits for symbol of type #{reference.kind}"
              end
              binary[reference.address] = binary[reference.address] & ~0b11_1111_1111 | ((value < 0 ? (2 ** 16) + value.bits(0...(16 - 1)) : value).to_u16 >> 6)
            in Object::Section::Reference::Kind::Lli 
              if value > 0b1111_1111_1111_1111 || value < - 0b1111_1111_1111_1111
                raise "Reference to #{name} = #{value} overflow from allowed 16 bits for symbol of type #{reference.kind}"
              end
              binary[reference.address] = binary[reference.address] & ~0b0111_1111 | ((value < 0 ? (2 ** 7) + value.bits(0...(7 - 1)) : value).to_u16 & 0x3f)
            in Object::Section::Reference::Kind::Beq
              value = value - reference.address - 1
              if value > 0b0011_1111 || value < - 0b0111_1111
                raise "Reference to #{name} = #{value} overflow from allowed 7 bits for symbol of type #{reference.kind}"
              end
              binary[reference.address] = binary[reference.address] & ~0b0111_1111 | (value < 0 ? (2 ** 7) + value.bits(0...(7 - 1)) : value).to_u16
          end
        end
      end
    end

    binary.each do |word|
      word.to_io io, ENDIAN
    end
    
  end
    
end
