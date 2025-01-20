require "ncurses"

module RiSC16
  abstract class Window
    getter x : Int32
    getter y : Int32
    getter width : Int32
    getter height : Int32
    getter title
    property focus : Bool = false

    def initialize(x, y, width, height, @title : String? = nil)
      @x = x.to_i
      @y = y.to_i
      @height = height.to_i
      @width = width.to_i
    end

    abstract def content(window : NCurses::Window)

    def draw
      NCurses::Window.subwin(x: @x, y: @y, height: @height, width: @width, parent: NCurses.stdscr) do |window|
        window.border
        @title.try do |title|
          window.attron(NCurses::Attribute::UNDERLINE) unless focus
          window.attron(NCurses::Attribute::REVERSE) if focus
          window.mvaddstr title.ljust(@width - 2, ' '), x: 1, y: 0
          window.attroff(NCurses::Attribute::UNDERLINE) unless focus
          window.attroff(NCurses::Attribute::REVERSE) if focus
        end
        content window
        window.refresh
      end
    end

    def up
    end

    def down
    end
  end

  class CustomWindow < Window
    def initialize(x, y, width, height, title = nil, &@block : NCurses::Window ->)
      super(x, y, width, height, title)
    end

    def content(window : NCurses::Window)
      @block.call(window)
    end
  end

  class Scroll < Window
    getter content_cursor : Int32
    getter line_cursor : Int32
    getter range : Range(Int32, Int32) | Range(Int32, Nil)

    def initialize(x, y, width, height, title = nil, @range = (0..), &@block : Int32 -> String?)
      super(x, y, width, height, title)
      @content_cursor = @range.begin
      @line_cursor = 1
    end

    def up
      @content_cursor = (@content_cursor - 1).clamp @range if @line_cursor == 1
      @line_cursor = (@line_cursor - 1).clamp(1, @height - 2)
    end

    def down
      @content_cursor = (@content_cursor + 1).clamp @range if @line_cursor == @height - 2 && (@range.end || Int32::MAX) - @content_cursor >= @height - 2
      @line_cursor = (@line_cursor + 1).clamp(1, @height - 2)
    end

    def center(n)
      @content_cursor = n - @height // 2 + 1
      @line_cursor = @height // 2
    end

    def cursor
      @range.begin + @content_cursor + @line_cursor - 1
    end

    def scroll_end
      @range.end.try do |last|
        @content_cursor = last - (@height - 2) + 1
        @line_cursor = @height - 2
      end
    end

    def content(window : NCurses::Window)
      (1..(@height - 2)).each do |line|
        window.attron(NCurses::Attribute::REVERSE) if line == @line_cursor
        content = @block.call(@content_cursor + line - 1)
        content ||= "".ljust(@width - 2, ' ') if line == @line_cursor
        window.mvaddstr content, x: 1, y: line if content
        window.attroff(NCurses::Attribute::REVERSE) if line == @line_cursor
      end
    end
  end

  class Table < Scroll
    def initialize(x, y, width, height, columns : Array(Int), title = nil, range = (0..), &block : Int32 -> Array(String)?)
      super(x, y, width, height, title, range) do |index|
        block.call(index).try &.map_with_index do |value, column|
          value[0, columns[column]].center(columns[column], ' ')
        end.join '|'
      end
    end
  end
end
