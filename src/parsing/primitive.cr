# fix the error management, it is almost useless now

# have a consume_while for better efficiency than one_or_more char pattern

class Parser
  @io : IO
  @error : String? = nil
  @checkpoint : Int32 | Int64 | Nil = nil
  
  UNEXPECTED_EOF = "Reached end of input unexpectedly"
  UNEXPECTED_VALUE = "Encountered unexpected value"

  def error
    @error
  end
  
  def initialize(@io, @debug = false) end

  def error(message)
    @error = "Error at position #{@io.tell}: #{message}"
    nil
  end

  def read_fully?
    if @io.peek.try &.empty? == true
      true
    else
      error "Unexpected input, Expected EOF"
    end
  end
  
  def eof
    error UNEXPECTED_EOF
  end

  def mismatch
    error UNEXPECTED_VALUE
  end

  def rollback
    @io.pos = @checkpoint || raise "Illegal rollback"
  end

  def checkpoint
    pos = @checkpoint = @io.tell
    value = yield
    @io.pos = pos unless value
    value
  end

  def consume_until(sample : String): String
    result = ""
    loop do
      value = @io.gets 1
      if value == nil
        break
      elsif value == sample
        @io.pos -= 1
        break
      else
        result += value.not_nil!
      end
    end
    result
  end
  
  def char(sample : Array(Char) | Char | Range(Char,Char) | Array(Range(Char, Char))): Char?
    checkpoint do
      case value = @io.gets(1).try &.char_at 0
      when nil then eof
      else
        case sample
        when Char then value if sample == value
        when Array(Char), Range(Char,Char) then value if sample.includes? value
        when Array(Range(Char, Char)) then value if sample.any?(&.includes? value)
        end
      end
    end
  end

  def str(sample : Array(String) | String): String?
    checkpoint do
      sample_size = case sample
      when String then sample.size
      when Array(String) then sample.map(&.size).max_by &.itself
      else 0
      end
      case value = @io.gets sample_size
      when nil then eof
      else
        case sample
        when String then value if sample == value
        when Array(String)
          sample.find do |subsample|
            subsample == value[0...(subsample.size)]
          end.try &.tap do |subsample|
            @io.pos = @io.tell - sample_size + subsample.size            
          end
        end
      end
    end
  end

  def whitespace
    one_or_more ->{ char [' ', '\t', '\r'] }
  end

  def multiline_whitespace
    one_or_more ->{ char [' ', '\t', '\r', '\n'] }
  end

  def or(*alternatives)
    checkpoint do 
      alternatives.each do |alt|
        case result = alt.call
        when nil then rollback
        else return result
        end
      end
    end
  end    
  
  def one_or_more(block : ->V?, separated_by : Proc(S)? = nil): Array(V)? forall V, S
    checkpoint do
      values = zero_or_more block, separated_by
      next if values.empty?
      values
    end
  end

  def zero_or_more(block : ->V?, separated_by : Proc(S)? = nil): Array(V) forall V, S
    checkpoint do
      results = [] of V
      loop do
        local_checkpoint = @io.tell
        unless results.empty? || separated_by.nil? 
          if separated_by.call.nil?
            @io.pos = local_checkpoint
            break
          end
        end
        if (result = block.call).nil?
          @io.pos = local_checkpoint
          break
        else
          results.push result
        end
      end
      results
    end
  end

  macro rule(prototype)
    def {{prototype.name}}
      checkpoint do
        {{prototype.body}}
      end
    end
  end
  
end
