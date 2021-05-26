require "ncurses"

  # A window
  abstract class Window < Composer::Composable
    getter x : Int32
    getter y : Int32
    getter width : Int32
    getter height : Int32
    getter title
    property focus : Bool = false

    def initialize(x = 0, y = 0, width = 0, height = 0, @title : String? = nil)
      @x = x.to_i
      @y = y.to_i
      @height = height.to_i
      @width = width.to_i
    end

    def geometry(@x, @y, @value, @height) end

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

    # A window with arbitrary content
    class Custom < Window
      def initialize(x = 0, y = 0, width = 0, height = 0, title = nil, &@block : NCurses::Window ->)
        super(x, y, width, height, title)
      end

      def content(window : NCurses::Window)
        @block.call(window)
      end
    end
  end  
