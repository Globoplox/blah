require "ncurses"
require "./window"


  # A window that can be scrolled
  class Scroll < Window
    getter content_cursor : Int32
    getter line_cursor : Int32
    getter range : Range(Int32, Int32) | Range(Int32, Nil)
    def initialize(x = 0, y = 0, width = 0, height = 0, title = nil, @range = (0..), &@block : Int32 -> String?)
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
        window.attron(NCurses::Attribute::REVERSE)  if line == @line_cursor
        content = @block.call(@content_cursor + line - 1)
        content ||= "".ljust(@width - 2, ' ') if line == @line_cursor
        window.mvaddstr content, x: 1, y: line if content
        window.attroff(NCurses::Attribute::REVERSE) if line == @line_cursor
      end
    end
  end

  # A scrolle window displaying columns
  class Table < Scroll
    def initialize(columns : Array(Int), x = 0, y = 0, width = 0, height = 0, title = nil, range = (0..), &block : Int32 -> Array(String)?)
      super(x, y, width, height, title, range) do |index|
        block.call(index).try &.map_with_index do |value, column|
          value[0, columns[column]].center(columns[column], ' ')
        end.join '|'
      end
    end
  end
