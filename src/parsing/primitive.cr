class Parser

  # Debug tree used for debugging
  property trace : Trace? = nil
  property trace_root : Trace? = nil

  class Trace
    @result : Node | String | Nil = nil
    getter result

    def result=(value)
      if value.is_a? Node
        @result = value
      elsif value.is_a? Array
        @result = value.map(&.to_s).join
      elsif value != nil
        @result = value.to_s
      end
    end
    
    property line : Int32
    property character : Int32
    property name : String?
    property subnodes : Array(Trace) = [] of Trace
    property trimmed = false
    property peek : String?
    
    def success?
      @result != nil
    end

    def trim
      @subnodes = @subnodes.first.subnodes if @subnodes.size > 0 && @name == "ONE OR MORE"
      case @name
      when "OR" then @subnodes.reject! &.success?
      when "ONE OR MORE", "ZERO OR MORE"
        summary = @subnodes.take_while &.success?
        if summary.size > 0
          summary.first.name = (summary.first.name || "Anonymous Node") + " succeded #{summary.size} times"
          summary.first.result = summary.map(&.result.to_s).join
          summary.first.subnodes.clear
          @subnodes = [summary.first] + @subnodes[(summary.size)..]
        end
      else 
        @subnodes.each_with_index do |node, index|
          node.subnodes.clear if node.success? && (index < @subnodes.size - 2) 
        end
      end
      @subnodes.reject! &.name.== "WS"
    end

    def compress
      if @subnodes.size == 1
        @name = "[...] #{@subnodes.first.name}"
        @subnodes = @subnodes.first.subnodes
      end
    end
  
    def initialize(@name, @line, @character, @peek = nil) end

    def format_input(input)
      if input != nil
        input = input.to_s if !input.is_a? String
        cut = false
        if input.count('\n') > 0
          input = input[0...(input.index '\n')]
        end
        if input.size > 60
          input = input[0..60]
          cut = true
        end
        input = "'#{input}'"
        input += "..."if cut
        input
      else
        "''"
      end
    end

    def dump(history = 3, prefix = "", io = STDOUT)
      io << String.build do |io|
        io << "\e[31m" if !success?
        io << prefix
        io << @name.try &.capitalize || "Anonymous node"
        io << ' '
        if success?
          io << "result: "
          io << format_input @result
        else
          io << "failed"
          unless @peek.nil?
            io << " near "
            io << format_input @peek
            io << " at line "
            io << @line
          end
        end
        io << "\e[0m" if !success?
        io << '\n' 
      end
      prefix = prefix.gsub({'├' => '│', '└' => ' '})
      @subnodes.each_with_index do |sub, index|
        if index != @subnodes.size - 1
          sub.dump history, prefix + " ├", io
        else
          sub.dump history, prefix + " └", io
        end
      end
    end

  end

  # Optional base type for ast node (or anything returned by a rule).
  abstract class Node 
    property line : Int32? = nil
    property character : Int32? = nil
  end

  record Checkpoint, position : Int32 | Int64, line : Int32, character : Int32, trace : Trace?

  @io : IO
  @checkpoint : Checkpoint = Checkpoint.new 0, 1, 1, nil
  @line : Int32 = 1
  @character : Int32 = 1

  def read_fully?
    checkpoint "EOF" do
      true if @io.peek.try &.empty? == true
    end
  end
  
  def initialize(@io, @debug = false) end

  def rollback
    @io.pos = @checkpoint.position
    @line = @checkpoint.line
    @character = @checkpoint.character
  end
  
  def checkpoint(name = nil)
    saved = @checkpoint = Checkpoint.new @io.tell, @line, @character, @trace
    if @debug
      current = @trace = Trace.new name, @line, @character, @io.peek.try { |peek| String.new peek }
      saved.trace.try do |root|
        root.subnodes << current
      end
      @trace_root ||= @trace
    end
    value = yield
    if @debug
      @trace.try do |trace|
        trace.result = value
        trace.trim
      end
    end
    @trace = saved.trace
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
    else
      @character += result.size
    end
    result
  end
  
  def char(sample : Array(Char) | Char | Range(Char,Char) | Array(Range(Char, Char))): Char?
    checkpoint "char like '#{sample}'" do
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
    checkpoint "string like '#{sample}'" do
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
      else
        @character += result.size
      end
    end
  end

  def whitespace
    checkpoint "WS" do
      one_or_more ->{ char [' ', '\t', '\r'] }
    end
  end

  def multiline_whitespace
    checkpoint "WS" do
      one_or_more ->{ char [' ', '\t', '\r', '\n'] }
    end
  end

  def or(*alternatives)
    checkpoint "OR" do
      working = nil
      alternatives.each do |alt|
        case result = alt.call
        when nil then rollback
        else
          working = result
          break
        end
      end
      working
    end
  end    
  
  def one_or_more(block : ->V?, separated_by : Proc(S)? = nil): Array(V)? forall V, S
    checkpoint "ONE OR MORE" do
      values = zero_or_more block, separated_by
      next if values.empty?
      values
    end
  end

  def zero_or_more(block : ->V?, separated_by : Proc(S)? = nil): Array(V) forall V, S
    checkpoint "ZERO OR MORE"  do
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
      checkpoint "{{d.name}}" do
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
