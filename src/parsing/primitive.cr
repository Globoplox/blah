# fix the error management, it is almost useless now

# have a consume_while for better efficiency than one_or_more char pattern

class Parser
  @io : IO
  @error : String? = nil
  @checkpoint : Int32 | Int64 | Nil = nil
  
  UNEXPECTED_EOF = "Reached end of input unexpectedly"
  UNEXPECTED_VALUE = "Encountered unexpected value"

  def summary
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
  
  def stack(description)
    yield
  end

  def rollback
    @io.pos = @checkpoint || raise "Illegal rollback"
  end

  def checkpoint(description)
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
    checkpoint "char '#{sample}'" do
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
    checkpoint "string '#{sample}'" do
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
    stack "whitespace" do
      one_or_more { char [' ', '\t', '\r'] }
    end
  end

  def multiline_whitespace
    stack "multiline whitespace" do
      one_or_more { char [' ', '\t', '\r', '\n'] }
    end
  end

  # Return the first non nil args, or nil if none match.
  # We need to checkpoint because nothing garantee us that rollbacking won't
  # bring us backward further than what we have consumed
  macro or(*args)
    {% raise "Rule 'or' need more than one argument" unless args.size > 1 %}
    checkpoint {{args.map(&.id).join " or "}} do
      {% for arg in args[0...-1] %}
        value = {{arg}}
        next value if value
        rollback
      {% end %}
      {{args[-1]}} || error "No matching alternative"
    end
  end

  def one_or_more(separated_by : Proc(S)? = nil, &block : ->V?): Array(V)? forall V, S
    checkpoint "one or more" do
      values = zero_or_more(separated_by: separated_by) { yield }
      next if values.empty?
      values
    end
  end

  def zero_or_more(separated_by : Proc(S)? = nil, &block : ->V?): Array(V) forall V, S
    stack "zero or more" do
      results = [] of V
      loop do
        local_checkpoint = @io.tell
        unless results.empty? || separated_by.nil? 
          if separated_by.call.nil?
            @io.pos = local_checkpoint
            break
          end
        end
        if (result = yield).nil?
          @io.pos = local_checkpoint
          break
        else
          results.push result
        end
      end
      results
    end
  end
  
end
