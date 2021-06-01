# fix the error management, it is almost useless now
class Parser
  VERSION = "0.1.0"

  @checkpoints = [] of (Int32 | Int64)
  @io : IO
  @error : String? = nil
  @stack = [] of String

  UNEXPECTED_EOF = "Reached end of input unexpectedly"

  UNEXPECTED_VALUE = "Encountered unexpected value"

  def summary
    @error
  end
  
  def initialize(@io, @debug = false) end

  # register an error
  def error(message)
    @error = String::Builder.build do |io|
      io << "Error at position "
      io << @io.tell
      io << ": "
      io << message
      io << "\n"
      @stack.reverse.each do |frame|
        io << frame
        io << "\n"
      end
    end
    nil
  end

  # True if read fully, false otherwise.
  # Use at the end of the root rule to ensure there is no dandling stuff at the end of input.
  def read_fully?
    if @io.peek.try &.empty? == true
      true
    else
      error "Unexpected input, Expected EOF"
    end
  end
  
  # register an eof error
  def eof
    error UNEXPECTED_EOF
  end

  # register a mismatch error
  def mismatch
    error UNEXPECTED_VALUE
  end
  
  # Optional parser for node that register them for debugging.
  # This does not allow for checkpoints, a node using this must
  # either never fail or not consume.
  # Rule of thumb is: it's okay to use this instead of `checkpoint` when wrapping a single consuming call.
  def stack(description)
    cursor = @stack.size
    @stack.push "#{description} at #{@io.tell}"
    yield.tap do @stack.pop end
  end

  # Rollback to the last checkpoint.
  # FIXME: do not use a stack, only a local variable (swap with previous value) cached into a property for use by reollback. 
  def rollback
    #puts "#{" " * @stack.size}rollbacking to #{@checkpoints[-1]}"
    @io.pos = @checkpoints[-1]
  end

  # Create a checkpoint and rollback in case of failure.
  # The rule to avoid mishap is that every parsing rule must rollback
  # to the state of the parser at the beginning of the ruel if they fail.
  # This is what checkpoint do.
  def checkpoint(description)
    stack description do
      a = @io.tell
      puts "#{"  " * @stack.size}trying #{description} at #{@io.tell}'" if @debug
      @io.pos = a
      @checkpoints.push @io.tell
      rollback unless value = yield
      #puts "#{" " * @stack.size}pop"
      @checkpoints.pop
      puts "#{"  " * @stack.size}OK" if value if @debug
      value
    end
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
  
  # Consume a single character that must match given sample.
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

  # Consume a single string that must match the given sample.
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

  # Consume whitespace.
  # Here we don't need a checkpoint because we don't consume anything ourselves before the call that
  # define if we failed or not.
  def whitespace(multiline = false)
    stack "whitespace" do
      if multiline
        one_or_more(char([' ', '\t', '\r', '\n']))
      else
        one_or_more(char([' ', '\t', '\r']))
      end
    end
  end

  def multiline_whitespace
    whitespace true
  end

  # TODO: remove ?
  def newlines
    checkpoint "newlines" do
      whitespace
      mandatory begin
        one_or_more(char('\n'), separated_by: begin
          whitespace
          true
        end).tap do  
          whitespace
        end
      end
    end
  end
  
  # Consume a newline
  # Here we might have consumed a '\r' before realising if the match failed or not.
  # So we need a checkpoint.
  # TODO optimize
  def newline
    checkpoint "newline" do
      char '\r'
      mandatory char '\n'
    end
  end

  # Macro for exiting from scope with nil when given expression is null, otherwise returning the given value.
  # This is usefull to mark an expression as being mandatory inside the scope of a checkpoint.
  # FIXME: make it more safe to use in loops ?
  # Or find a better way ? maybe could be replaced by a cosntrut such as
  # next unless var = expression
  # this is more explisite that this magic macro
  macro mandatory(expr)
    begin
      value_%_ = begin {{expr}} end
      next mismatch if value_%_.nil?
      value_%_.not_nil!
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

  # Return a tuple of args or nil if any call is nil
  # FIXME: Useless ?
  macro and(*args)
    {% raise "Rule 'and' need more than one argument" unless args.size > 1 %}
    checkpoint {{args.map(&.id).join " and "}} do
      {% for arg, index in args %}
        value_{{index}} = {{arg}}
        next nil unless value_{{index}}
      {% end %}
      {
        {% for arg, index in args[0...-1] %}
          value_{{index}},
        {% end %}
        value_{{args.size - 1}}
      }
    end
  end

  # Return an array of the consumed arg, or nil if first call is nil
  # FIXME: use a zero_or_more and a nil if empty ?
  macro one_or_more(arg, separated_by = Nil)
    stack %{One or more {{arg}}} do
      results_%_ = [] of typeof({{arg}})
      loop do
        checkpoint_%_ = @io.tell
        {% if separated_by != Nil %}
          begin
            begin
              @io.pos = checkpoint_%_
              break
            end unless {{separated_by}}
          end unless results_%_.empty?
        {% end %}
        result_%_ = {{arg}}
        begin
          @io.pos = checkpoint_%_
          break
        end if result_%_.nil?
        results_%_.push result_%_.not_nil!
      end
      if results_%_.empty?
        error "Matched zero times"
      else
        results_%_.compact
      end
    end
  end

  # Return an array of the consumed arg. Never fail.
  # Fixme: make it a function with blocks ? maybe use proc for the separated by, unless this has bad perf ?
  macro zero_or_more(arg, separated_by = Nil)
    stack %{Zero or more {{arg}}} do
      results_%_ = [] of typeof({{arg}})
      loop do
        checkpoint_%_ = @io.tell
        {% if separated_by != Nil %}
          unless results_%_.empty?
            separator_%_ = {{separated_by}}
            if separator_%_.nil?
              @io.pos = checkpoint_%_
              break
            end
          end
        {% end %}
        result_%_ = {{arg}}
        begin
          @io.pos = checkpoint_%_
          break
        end if result_%_.nil?
        results_%_.push result_%_.not_nil!
      end
      results_%_.compact.not_nil!
    end.not_nil!
  end

end
