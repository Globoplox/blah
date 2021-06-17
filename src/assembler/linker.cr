require "../risc16"
require "./object"

module RiSC16::Linker
  extend self

  ENDIAN = IO::ByteFormat::BigEndian
  
  def symbols_from_spec(spec)
    predefined_symbols = {} of String => Object::Section::Symbol
    predefined_symbols["__stack"] = Object::Section::Symbol.new spec.stack_start.to_i32, false
    spec.io.each do |io|
      absolute = (spec.io_start + io.index).to_i32
      relative = - (UInt16::MAX.to_i32 - absolute + 1)
      predefined_symbols["__io_#{io.name}_a"] = Object::Section::Symbol.new absolute, false
      predefined_symbols["__io_#{io.name}_r"] = Object::Section::Symbol.new relative, false
    end
    predefined_symbols
  end

  def link_to_binary(spec, objects, io)
    predefined_section_size = {} of String => Int32
    predefined_section_address = {} of String => Int32

    globals = symbols_from_spec(spec)

    # check for conflict between exported symbols
    objects.each &.sections.each &.definitions.each do |(name, symbol)|
      raise "duplicate global symbol #{name}" if globals[name]?
      globals[name] = symbol                                                   
    end
    
    # Set all the texts, symbols and references address
    # by ordering all "sections", then each fragment of this section
    # and adding the size of each. Raise when constraint is not possible and jump directly to offset when their are gaps
    text_size = objects.flat_map(&.sections).group_by(&.name).to_a.sort_by do |(name, sections)|
      predefined_section_address[name]? || Int32::MAX
    end.reduce(0) do |absolute, (name, sections)|
      base = predefined_section_address[name]? || absolute
      raise "Section #{name}, cannot overwrite at offset #{base}, there are already data up to #{absolute}" if base < absolute
      sections.sort_by { |section| section.offset || Int32::MAX }.reduce(base) do |absolute, section|
        raise "Block offset conflict in section #{name}, cannot overwrite at offset #{section.offset}, there are already data up to #{absolute}" if section.offset || 0 < absolute
        section.offset ||= absolute
        section.definitions.values.each do |symbol|
          symbol.address = symbol.address + section.offset.not_nil!
        end
        section.references.values.each &.each do |ref|
          ref.address = (ref.address.to_i32 + section.offset.not_nil!).to_u16
        end
        section.offset.not_nil! + section.text.size
      end
    end

    # check that text_size does not overflow ram ?

    binary = Slice(UInt16).new text_size
    
    # write to file
    # perform references replacement
    objects.each &.sections.each do |section|
      # we accept only section defined symbols, not object defined symbols. We could do the opposite easily, but do we want to ? => yes, for static stuff
      # todo: update this ? or else we could not. This would ease having static near in memory to where they should be. 
      symbols = globals.merge section.definitions.reject { |name, symbol| symbol.exported } 
      section.text.copy_to binary[(section.offset.not_nil!)...(section.offset.not_nil! + section.text.size)]
      section.references.each do |name, references|
        symbol = symbols[name]? || raise "Undefined reference to symbol '#{name}'"
        references.each do |reference|
          pp "Handling reference to #{name} at address #{reference.address} (type #{reference.kind})"
          value = symbol.address + reference.offset
          case reference.kind
            in Object::Section::Reference::Kind::Data
              if value > 0b_0111_1111_1111_1111 || value < - 0b_1111_1111_1111_1111
                raise "Reference to #{name} overflow from allowed 16 bits for symbol of type #{reference.kind}"
              end
              binary[reference.address] = (value < 0 ? (2 ** 16) + value.bits(0...(16 - 1)) : value).to_u16
            in Object::Section::Reference::Kind::Imm
              if value > 0b_0011_1111 || value < - 0b_0111_1111
                raise "Reference to #{name} overflow from allowed 7 bits for symbol of type #{reference.kind}"
              end
              binary[reference.address] = binary[reference.address] & ~0b_0111_1111 | (value < 0 ? (2 ** 7) + value.bits(0...(7 - 1)) : value).to_u16
            in Object::Section::Reference::Kind::Lui
              if value > 0b_0111_1111_1111_1111 || value < - 0b_1111_1111_1111_1111
                raise "Reference to #{name} overflow from allowed 16 bits for symbol of type #{reference.kind}"
              end
              binary[reference.address] = binary[reference.address] & ~0b_11_1111_1111 | ((value < 0 ? (2 ** 16) + value.bits(0...(16 - 1)) : value).to_u16 >> 6)
            in Object::Section::Reference::Kind::Lli 
              if value > 0b_0011_1111 || value < - 0b_0111_1111
                raise "Reference to #{name} overflow from allowed 7 bits for symbol of type #{reference.kind}"
              end
              binary[reference.address] = binary[reference.address] & ~0b_0111_1111 | ((value < 0 ? (2 ** 7) + value.bits(0...(7 - 1)) : value).to_u16 & 0x3f)
            in Object::Section::Reference::Kind::Beq
              value = value - reference.address - 1
              if value > 0b_0011_1111 || value < - 0b_0111_1111
                raise "Reference to #{name} overflow from allowed 7 bits for symbol of type #{reference.kind}"
              end
              binary[reference.address] = binary[reference.address] & ~0b_0111_1111 | (value < 0 ? (2 ** 7) + value.bits(0...(7 - 1)) : value).to_u16
          end
        end
      end
    end

    binary.each do |word|
      word.to_io io, ENDIAN
    end
    
  end
    
end

require "./parser"
require "./assembler"
require "../spec"

spec = RiSC16::Spec.open "./specs/tty.ini", {} of String => String 
ast =  RiSC16::Assembler::Parser.new(IO::Memory.new(ARGF.gets_to_end), false).unit
if ast
  object = RiSC16::Assembler.assemble ast
  if object
    File.open "v2.out", "w" do |output|
      RiSC16::Linker.link_to_binary spec, [object], output
    end
  end
end
