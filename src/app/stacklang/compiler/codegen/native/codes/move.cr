class Stacklang::Native::Generator
  def compile_move(code : ThreeAddressCode::Move)
    source_meta = @addresses[root_id code.address]
    into_meta = @addresses[root_id code.into]

    if into_meta.spillable.never?
      raise "Cannot move to unspillable address #{code.into}, not a valid LValue"
    end

    if code.address.size != code.into.size
      raise "Size mismatch in allocation #{code}"
    elsif code.into.size == 1
      # Load address
      right = load code.address

      # If source is spillable never or spillable always, it is safe to steal the cache
      # because it wont be used and will be deleted anyway
      # If source is spillable yes but will not be used after this, it is safe to steal the cache

      # IF a = a

      # If source is spillable never it's safe to steal the cache, but this may be detrimental if the value is reused
      # in which case, it's better to take a new register and let future grab_free decide on which is best to unload
      # We never steel R0 because it is badly supported by other cache/spill routines as several could be hosted in r0
      # leading to forgetting that some value are hosted and not spilled
      # This COULD be fixed but is hard to do.
      if right != ZERO_REGISTER && (source_meta.spillable.always? || source_meta.used_at.max <= @index)
        source_meta.set_live_in_register for: code.address, register: nil

        # if dest is hosted, must un-host it as it will be assigned another register
        into_reg = into_meta.live_in_register for: code.into
        if into_reg
          @registers[into_reg] = nil
        end

        into_meta.set_live_in_register for: code.into, register: right
        @registers[right] = code.into
        # Standard way, grab and copy
      else
        into = grab_for code.into
        add into, right, ZERO_REGISTER
      end

      clear({code.address}, {code.into})
    else
      # TODO
      raise "Multi word move is unsupported yet"
    end
  end
end
