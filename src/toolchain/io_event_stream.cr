require "option_parser"
require "colorize"
require "./toolchain"
require "./debugger"

# Implement an event stream that simply log to 
# an io with a few ansi colors and effects. 
class Toolchain::IOEventStream < Toolchain::EventStream

  def initialize(@out : IO)
  end

  protected def location(source : String?, line : Int32?, column : Int32?) : String?
    location = [] of String
    location << "in '#{source}'" if source
    location << "at #{emphasis("line #{line}")}" if line
    location << "column #{column}" if column
    return nil if location.empty?
    location.join " "
  end

  def emphasis(str)
    str.colorize.bold.underline
  end

  protected def event_impl(level : Level, title : String, body : String?, locations : Array({String?, Int32?, Int32?}))
    @out << case level
      in Level::Warning then level.colorize(:yellow).bold
      in Level::Error then level.colorize(:red).bold
      in Level::Fatal then level.colorize(:red).bold
      in Level::Context then level.colorize(:grey).bold
      in Level::Success then level.colorize(:green).bold
    end
  
    @out << ": "
    @out << title

    locations = locations.compact_map do |(source, line, column)|
      location(source, line, column)
    end

    if locations.empty?
      @out << '\n'
    elsif locations.size == 1 && (body || @context.empty?)
      @out << " "
      @out << locations.first
      @out << '\n'
    else
      @out << '\n'
      locations.each do |location|
        @out << "- "
        @out << location.capitalize
        @out << '\n'
      end
    end

    @out.puts body if body && !body.empty?

    @context.reverse_each do |(title, source, line, column)|
      @out << "While "
      @out << title
      location(source, line, column).try do |l| 
        @out << " "
        @out << l
      end
      @out << '\n'
    end
    
    @out.puts if !@context.empty?
  end

end