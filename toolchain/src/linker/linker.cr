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

  # Link several objects into a single object.
  # It set the `absolute` field of section, which mean
  # Attributing them an absolute location, assuming a loading location of 0.
  def merge(spec : Spec, objects : Array(RiSC16::Object), destination_name, events) : RiSC16::Object
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
    deduplicates = {} of String => Array({String?, Int32?, Int32?})
    globals.each do |(name, _)|
      (deduplicates[name] ||= Array({String?, Int32?, Int32?}).new) << {spec.path, nil, nil}
    end

    # check for conflict between exported symbols
    objects.each do |object| 
      object.sections.each do |section| 
        section.definitions.each do |(name, symbol)|
          next unless symbol.exported
          (deduplicates[name] ||= Array({String?, Int32?, Int32?}).new) << {object.name, nil, nil}
          globals[name] = symbol
        end
      end
    end

    deduplicates.each do |name, sources|
      if sources.size > 1
        events.event(
          level: :error,
          body: nil,
          title: "Duplicate global symbol #{events.emphasis(name)}",
          locations: sources
        )
      end
    end

    if events.errored
      events.fatal!(title: "Merging failed at symbol conflict check") {}
    end

    # Set all the texts, symbols and references address
    # by ordering all "sections", then each fragment of this section
    # and adding the size of each. Raise when constraint is not possible and jump directly to offset when their are gaps
    # TODO: dump layout in case of overflow
    # TODO: otpimize size by compacting ?
    # Since we don't overwrite offsets or address, it is now possible to re-merge objects.
    text_size = objects.flat_map(&.sections).group_by(&.name).to_a.sort_by do |(name, sections)|
      predefined_section_address[name]? || Int32::MAX
    end.reduce(start) do |absolute, (name, sections)|
      fixed = predefined_section_address[name]?.try &.to_i32
      base = fixed || absolute
      
      if base < absolute
        events.fatal!(title: "Section merge conflict") do |io|
          io << "Section #{events.emphasis(name)} cannot overwrite at offset #{events.emphasis(base)}, there are already data up to #{events.emphasis(absolute)}" 
        end
      end

      # `base` is an absolute address of where we want to start writing the blocks for the current section
      sections.sort_by { |section| section.offset || Int32::MAX }.reduce(base) do |absolute, section|
        # `absolute`: is an absolute address of where we CAN begin writing stuff.
        # `section.offset`, is an offset to `base` were we WANT to begin writing stuff.
        if base + (section.offset || UInt16::MAX) < absolute
          events.fatal!(title: "Section merge conflict") do |io|
            io << "Block offset conflict in section #{events.emphasis(name)}, cannot overwrite at #{events.emphasis(base)} + #{events.emphasis(section.offset)}, there are already data up to #{events.emphasis(absolute)}"
          end
        elsif section.offset
          absolute = base + (section.offset || 0)
        end
        section.absolute = absolute
        # We do not replace the address, they stay relative to the start of the code block.
        absolute + section.text.size
      end.tap do |at_end|
        size = at_end - base
        max = predefined_section_size[name]? || Int32::MAX
        if size > max
          events.fatal!(title: "Section merge conflict") do |io|
            io << "Section #{events.emphasis(name)} of size #{events.emphasis(size)} overflow maximum size constraint #{events.emphasis(max)}" 
          end
        end
      end
    end

    RiSC16::Object.new(name: destination_name).tap do |object|
      objects.each &.sections.each do |section|
        object.sections << section
      end
      object.merged = true # indicate that the object is valid and has offset. that's all.
    end
  end

  def strip_unused(object)
    object.sections.each do |section|
      section.definitions.reject! do |name, symbol|
        !symbol.exported && (!section.references[name]? || section.references[name].empty?)
      end
    end
  end

  # If a section contain a BEQ reference to a symbol defined in the same section,
  # it can be linked without knowing the absolute section location
  # because BEQ symbol are relative to definition
  def link_local_beq(section : RiSC16::Object::Section, events)
    section.references.each do |name, references|
      next unless symbol = section.definitions[name]?
      rem = [] of RiSC16::Object::Section::Reference
      references.each do |reference|
        next unless reference.kind.beq?
        value = symbol.address + reference.offset - reference.address - 1
        if value > 0b111111 || value < -0b1111111
          events.fatal!(title: "Section merge conflict") do |io|
            io << "Reference to #{events.emphasis(name)} = #{events.emphasis(value)} overflow from allowed 7 bits for symbol of type #{events.emphasis(reference.kind)}"
          end
        end
        section.text[reference.address] = section.text[reference.address] & ~0b0111_1111 | (value < 0 ? (2 ** 7) + value.bits(0...6) : value).to_u16
        rem << reference
      end
      references.reject! &.in? rem
    end
    section.references.reject! { |_, v| v.empty? }
  end

  def link_local_beq(object : RiSC16::Object, events)
    object.sections.each do |section|
      link_local_beq section, events
    end
  end

  # Static link an object into a binary blob, expected to be loaded at a given lovation (default to 0).
  # It performs the final symbols/value substitution.
  # This is the piece of code that would be necessary to bootstrap to be able to
  # dynamically load programs from another program (this would also work for loading dynamic libraries).
  def static_link(spec, object, io, events, start : Int32 = 0)
    if object.merged == false
      events.fatal!(title: "Link Error", source: object.name) do |io|
        io << "Cannot link unmerged object"
      end
    end

    link_local_beq object, events
    strip_unused object

    globals = symbols_from_spec(spec).transform_values do |symbol|
      Tuple(Object::Section::Symbol, Object::Section?).new symbol, nil
    end
    # TODO:
    # Couldnt we generate a section for those globals so they are stored within the object file after mergeing ?
    # That would also allow to check for conflict. Less work for bootstraping to.
    # TODO: store max_size ? so we don't need to recompute it.

    object.sections.each do |section|
      section.definitions.each do |(name, symbol)|
        next unless symbol.exported
        globals[name] = {symbol, section}
      end
    end

    max = object.sections.max_by do |section|
      section.absolute.not_nil! + section.text.size
    end
    text_size = max.absolute.not_nil! + max.text.size - start

    binary = Slice(UInt16).new text_size # No padding, start at *start*

    object.sections.each do |section|
      symbols = globals.merge section.definitions.reject { |name, symbol| symbol.exported }.transform_values { |definition|
        {definition, section}
      }

      block_location = section.absolute.not_nil! - start
      section.text.copy_to binary[block_location...(block_location + section.text.size)]
      section.references.each do |name, references|
        symbol, symbol_section = symbols[name]? || begin
          events.error(title: "Undefined Reference to #{events.emphasis(name)} in section #{events.emphasis(section.name)}", source: object.name) {}
          next
        end
        references.each do |reference|
          value = symbol.address + (symbol_section.try(&.absolute) || 0) + reference.offset
          reference_address = section.absolute.not_nil! + reference.address - start

          case reference.kind
          in Object::Section::Reference::Kind::Data
            if value > 0b1111_1111_1111_1111 || value < -0b1111_1111_1111_1111
              events.error(title: "Reference Overflow", source: object.name) do |io|
                io << "Reference to #{events.emphasis(name)} = #{events.emphasis(value)} overflow from allowed 16 bits for symbol of type #{events.emphasis(reference.kind)} in section #{events.emphasis(section.name)}"
              end
            else
              binary[reference_address] = (value < 0 ? (2 ** 16) + value.bits(0...(16 - 1)) : value).to_u16
            end
          in Object::Section::Reference::Kind::Imm
            if value > 0b0011_1111 || value < -0b0111_1111
              events.error(title: "Reference Overflow", source: object.name) do |io|
                io << "Reference to #{events.emphasis(name)} = #{events.emphasis(value)} overflow from allowed 7 bits for symbol of type #{events.emphasis(reference.kind)} in section #{events.emphasis(section.name)}"
              end
            else
              binary[reference_address] = binary[reference_address] & ~0b0111_1111 | (value < 0 ? (2 ** 7) + value.bits(0...(7 - 1)) : value).to_u16
            end
          in Object::Section::Reference::Kind::Lui
            if value > 0b1111_1111_1111_1111 || value < -0b1111_1111_1111_1111
              events.error(title: "Reference Overflow", source: object.name) do |io|
                io << "Reference to #{events.emphasis(name)} = #{events.emphasis(value)} overflow from allowed 16 bits for symbol of type #{events.emphasis(reference.kind)} in section #{events.emphasis(section.name)}"
              end
            else
              binary[reference_address] = binary[reference_address] & ~0b11_1111_1111 | ((value < 0 ? (2 ** 16) + value.bits(0...(16 - 1)) : value).to_u16 >> 6)
            end
          in Object::Section::Reference::Kind::Lli
            if value > 0b1111_1111_1111_1111 || value < -0b1111_1111_1111_1111
              events.error(title: "Reference Overflow", source: object.name) do |io|
                io << "Reference to #{events.emphasis(name)} = #{events.emphasis(value)} overflow from allowed 16 bits for symbol of type #{events.emphasis(reference.kind)} in section #{events.emphasis(section.name)}"
              end
            else
              binary[reference_address] = binary[reference_address] & ~0b0111_1111 | ((value < 0 ? (2 ** 7) + value.bits(0...(7 - 1)) : value).to_u16 & 0x3f)
            end
          in Object::Section::Reference::Kind::Beq
            value = value - (reference.address + section.absolute.not_nil!) - 1
            if value > 0b0011_1111 || value < -0b0111_1111
              events.error(title: "Reference Overflow", source: object.name) do |io|
                io << "Reference to #{events.emphasis(name)} = #{events.emphasis(value)} overflow from allowed 7 bits for symbol of type #{events.emphasis(reference.kind)} in section #{events.emphasis(section.name)}"
              end
            else
              binary[reference_address] = binary[reference_address] & ~0b0111_1111 | (value < 0 ? (2 ** 7) + value.bits(0...(7 - 1)) : value).to_u16
            end
          end
        end
      end
    end

    if events.errored
      events.fatal!(title: "Linker error") do |io|
        io << "A fatal error interrupted executable linking"
      end
    end

    binary.each do |word|
      word.to_io io, ENDIAN
    end
  end
end
