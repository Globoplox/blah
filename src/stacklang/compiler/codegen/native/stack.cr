# Represent a dynamic stack on which addresses may or must be spilled.
struct Stacklang::Native::Generator::Stack
  alias Index = Int32
  @slots = [] of {ThreeAddressCode::Address | Int32, Int32} # {address | free size, real stack offset}

  def to_s(io)
    @slots.each_with_index do |(entry, offset), index|
      case entry
      in ThreeAddressCode::Address then io.puts "Slot #{index}: #{entry} (size: #{entry.size}) (real stack offset: #{offset})"
      in Int32 then io.puts "Slot #{index}: FREE (size: #{entry}) (real stack offset: #{offset})"
      end
    end
  end
  
  def size
    return 0 if @slots.empty?
    (@slots.size - 1).downto(0) do |ri|
      entry, offset = @slots[ri]
      case entry
        in ThreeAddressCode::Address then return offset + entry.size
        in Int32 then next
      end
    end
    return 0
  end

  # Legacy. 
  # TODO: remove this and its usage
  def offset_at(index : Index) : Int32
    index
  end

  def allocate(address : ThreeAddressCode::Address) : Index
    enforced = address.as?(ThreeAddressCode::Local).try &.abi_expected_stack_offset
    if enforced
      # At end of current stack ?
      offset = size

      if offset == enforced
        @slots << {address, offset}
        return offset
      elsif offset < enforced
        @slots << {enforced - offset, offset}
        @slots << {address, enforced}
        return enforced
      end

      # Within current stack 
      @slots.each_with_index do |(entry, offset), index|
        case entry
        in ThreeAddressCode::Address then next
        in Int32
          if offset == enforced && entry == address.size
            @slots[index] = {address, offset}
            return enforced
          elsif offset == enforced && entry > address.size
            @slots[index, 1] = [{address, offset}, {entry - address.size, offset + address.size}]
            return enforced
          elsif offset < enforced && entry == enforced - offset + address.size
            @slots[index, 1] = [{enforced - offset, offset}, {address, enforced}]
            return enforced
          elsif offset < enforced && entry > enforced - offset + address.size 
            @slots[index, 1] = [{enforced - offset, offset}, {address, enforced}, {entry -(address.size - enforced - offset), enforced + address.size}]
            return enforced
          elsif offset > enforced
              raise "Cannot allocate #{address} at enforced stack offset #{enforced}, offset is not free" 
          end
        end
      end
      raise "Cannot allocate #{address} at enforced stack offset #{enforced}, offset is not free"
  
    else
      @slots.each_with_index do |(entry, offset), index|
        case entry
        in ThreeAddressCode::Address then next
        in Int32
          if entry == address.size
            @slots[index] = {address, offset}
            return offset
          elsif entry > address.size
            @slots[index, 1] = [{address, offset}, {entry - address.size, offset + address.size}]
            return offset
          else next
          end
        end
      end

      offset = size
      @slots << {address, offset}
      offset
    end
  end

  def free(index : Index)
    # Scan to find the right block
    given_offset = index
    index = nil
    @slots.each_with_index do |(entry, offset), i|
      if offset == given_offset
        index = i
        break
      end
    end
    unless index
      raise "Could not find a stack block with index #{index}"
    end

    current = @slots[index]
    start = index
    count = 1
    entry = current[0]
    total_size = case entry
      in ThreeAddressCode::Address then entry.size
      in Int32 then entry
    end
    base_address = current[1]

    @slots[index - 1]?.try do |entry, base|
      entry.as?(Int32).try do |free_size|
        count += 1
        base_address = base
        start = index - 1
        total_size += free_size
      end
    end

    @slots[index + 1]?.try do |entry, base|
      entry.as?(Int32).try do |free_size|
        count += 1
        total_size += free_size
      end
    end

    @slots[start...(start + count)] = [{total_size.as(ThreeAddressCode::Address | Int32), base_address}]
  end
end