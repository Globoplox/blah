require "ncurses"

class Composer
  
  abstract class Composable
    abstract def geometry(x, y, value, height)
  end
  
  class Graph < Composable
    
    enum Orientation
      Horizontal
      Vertical
    end

    enum Type
      Absolute
      Percentage
    end

    # If sticky, the last (if start) or first (if end) leaf is given all reamining space
    enum Sticky
      Start
      End
    end
    
    @orientation : Orientation
    @kind : Type
    @sticky : Sticky?
    @tmp_sticky = false
    @leafs : Array(Composable)
    @spread : Array(Int32)
    @parent : Graph?

    def initialize(@orientation, @parent = nil, @kind = Type::Percentage, @sticky = nil, @leafs = [] of Composable, @spread = [] of  Int32) end

    def add(node, value)
      raise "Cannot add node after stick set to end" if @sticky.try &.end?
      @leafs << node
      if value
        @spread << value
      else # stick start then ok, has begun stick end then ok too else shit happening
        raise "Missing value for non sticky node" unless @tmp_sticky || @sticky.try &.start?
      end
      with node yield node
    end
    
    # add a new vertical node leaf
    def vertical(value = nil)
      add Graph.new(Orientation::Vertical, parent: self), value do with self yield self end
    end

    # add a new horizontal node leaf
    def horizontal(value = nil)
      add Graph.new(Orientation::Horizontal, parent: self), value do with self yield self end
    end

    # add a new window leaf
    def window(value, window)
      add window, value do end
    end

    # add a new window leaf
    def window(window)
      add window, nil do end
    end

    # make the current node absolute
    def absolute
      @kind = Type::Absolute
    end

    # add a node and make stick. If there is already a leaf, sticky end. Else stick start. If already stick_end, raise. 
    def sticky(node)
      sticky node do end
    end

    def sticky(node, &block)
      if @leafs.empty?
        @sticky = Sticky::Start
        add node, nil do with self yield self end
      else
        @tmp_sticky = true
        add node, nil do with self yield self end
        @sticky = Sticky::End        
      end
    end
        
    # recompute assuming whole screen.
    def compute()
      geometry(0, 0, NCurses.maxx, NCurses.maxy)
    end

    def check(x, y, value, height)
      raise "Horizontal Overlow: #{@spread.sum} > #{width}" if @orientation.horizontal? && @kind.absolute? && @spread.sum > width
      raise "Vertical Overlow: #{@sprea.sum} > #{height}" if @orientation.vertical? && @kind.absolute? && @spread.sum > height
      raise "Percentage Overlow: #{@spread.sum} > 100" if @kind.percentage? && @spread.sum > 100
      # ....
    end

    # recompute each subnode size
    def geometry(x, y, value, height)
      if @sticky
        remain = case {@kind, @orientation}
        in {Type::Percentage, _} then 100
        in {Type::Absolute, Orientation::Horizontal} then width 
        in {Type::Absolute, Orientation::Vertical} then height
        end - @spread.sum
        case @sticky
        when Start then @spread.push remain
        when End then @spread.shift remaine
        end
      end
      leafs.zip spread do |leaf, value|
        case {@orientation, @kind}
        when {Orientation::Horizontal, Type::Absolute}
          leaf.geometry(x, y, value, height)
          x += value
        when {Orientation::Vertical, Type::Absolute} then
          leaf.geometry(x, y, width, y)
          y += value
        when {Orientation::Horizontal, Type::Percentage} then
          leaf.geometry(x, y, value * width // 100, height)
          x += value * width // 100
        when {Orientation::Vertical, Type::Percentage} then
          leaf.geometry(x, y, width, value * height // 100)
          y += value * height // 100
        end
      end
    end

    def draw()
      @leafs.each &.draw
    end

    def traverse
      @leafs.reduce [] of Window do |windows, leaf|
        case leaf
        when Window then windows << leaf
        when Graph then windows + leaf.traverse
        else windows
        end
      end
    end
  end

  @root = Graph.new Graph::Orientation::Horizontal
  property windows = [] of Window
    
  def configure
    with @root yield @root
    @root.compute 0, 0, 80, 50
    windows = @root.traverse
  end
  
  def run
    NCurses.open do
      NCurses.cbreak
      NCurses.noecho
      NCurses.keypad true
      NCurses.notimeout true
      window_cursor = 0
      @root.draw()
      loop do
        windows.each &.draw
        case {focus.nil?, input = NCurses.getch} 
        when {_, 'q'}, {_, NCurses::KeyCode::ESC} then break
        when {false, NCurses::KeyCode::LEFT}
          window_cursor = (window_cursor - 1) % windows.size
          windows.each_with_index { |window, index| window.focus = index == window_cursor }
        when {false, NCurses::KeyCode::RIGHT}
          window_cursor = (window_cursor + 1) % windows.size
          windows.each_with_index { |window, index| window.focus = index == window_cursor }
        when {false, NCurses::KeyCode::UP} then windows[window_cursor]?.try &.up
        when {false, NCurses::KeyCode::DOWN} then windows[window_cursor].try &.down
        else yield input
        end      
        NCurses.clear
      end
    end
  end
end
