class Parser

  abstract class Node
    property line : Int32? = nil
    property character : Int32? = nil
  end

  record Checkpoint, position : Int32 | Int64, line : Int32, character : Int32 

  @io : IO
  @checkpoint : Checkpoint = Checkpoint.new 0, 1, 1
  @line : Int32 = 1
  @character : Int32 = 1

  def read_fully?
    true if @io.peek.try &.empty? == true
  end
  
  def initialize(@io, @debug = false) end

  def rollback
    @io.pos = @checkpoint.position
    @line = @checkpoint.line
    @character = @checkpoint.character
  end

  def checkpoint
    saved = @checkpoint = Checkpoint.new @io.tell, @line, @character
    value = yield
    @checkpoint = saved
    rollback unless value
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
    if (lines = result.count '\n') != 0
      @line += lines
      @character = (result.reverse.index '\n') || 0
    end
    result
  end
  
  def char(sample : Array(Char) | Char | Range(Char,Char) | Array(Range(Char, Char))): Char?
    checkpoint do
      case value = @io.gets(1).try &.char_at 0
      when nil then nil
      else
        case sample
        when Char then value if sample == value
        when Array(Char), Range(Char,Char) then value if sample.includes? value
        when Array(Range(Char, Char)) then value if sample.any?(&.includes? value)
        end
      end
    end.tap &.try do |result|
      if result == '\n'
        @line += 1
        @character = 0
      else
        @character += 1
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
      when nil then nil
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
    end.tap &.try do |result|
      if (lines = result.count '\n') != 0
        @line += lines
        @character = (result.reverse.index '\n') || 0
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

  macro rule(definition)
    {% d = definition %}
    def {{d.receiver}}{{d.receiver ? ".".id : "".id}}{{d.name}}({{d.args.splat}}){{d.return_type ? ":" : "".id}}{{d.return_type}}
      checkpoint do
        {{d.body}}
      end.tap do |result|
        if result.is_a? Node
          result.line = @line
          result.character = @character
        end
      end
    end
  end
  
end
