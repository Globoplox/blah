require "./vm"
require "./spec"
require "ncurses"

module RiSC16

  class Debugger

    @unit : Assembler::Unit
    @input = IO::Memory.new
    @output = IO::Memory.new
    @vm : VM
    @locs : Hash(UInt16, Array(Assembler::Loc))
    @cursor = 0
    @spec : Spec
    
    def initialize(@unit, io, @spec)
      @vm = VM.from_spec(@spec, io_override: {"tty" => VM::MMIO.new(@input, @output)}).tap &.load io
      @locs = {} of UInt16 => Array(Assembler::Loc)
      unit.each_with_address do |address, loc|
        (@locs[address] = @locs[address]? || [] of Assembler::Loc).push loc
      end
    end

    def run
      NCurses.open do
        cx = NCurses.maxx
        cy = NCurses.maxy
        NCurses.cbreak
        NCurses.noecho
        NCurses.keypad true
        NCurses.notimeout true

        loop do
          code
          registers
          io
          stack
          
          case NCurses.getch
          when 'q', NCurses::KeyCode::ESC then break
          when 's' then @vm.step
          when 'c'
            loop do
              @vm.step
              break if @vm.halted
            end
          when NCurses::KeyCode::UP then @cursor -= 1
          when NCurses::KeyCode::DOWN then @cursor += 1
          end

          NCurses.clear
        end
      end

      
    end

    def code
      h = NCurses.maxy - 2
      w = NCurses.maxx // 2
      cursor_loc = [] of Assembler::Loc
      NCurses::Window.subwin x: 0, y: 0, height: NCurses.maxy, width: w, parent: NCurses.stdscr do |win|
        win.border
        index = 0
        real_index = 0
        cursor_index = 0
        @cursor = 0 if @cursor < 0
        while index < h - 2
        pc = (real_index - (h - 2) // 2) + @vm.pc
          
          if pc < 0 || pc >= @vm.ram.size
            real_index += 1
            index += 1
            next
          end

          locs = @locs[pc]?
          size = locs.try &.size || 1
          
          win.attron(NCurses::Attribute::UNDERLINE) if pc == @vm.pc
          win.attron(NCurses::Attribute::BOLD) if cursor_index == @cursor
          win.mvaddstr("0x#{pc.to_s(base:16).rjust(4, '0')}: 0b#{@vm.ram[pc].to_s(base:2).rjust(16, '0')}", x: 1, y: 1 + index)
          win.attroff(NCurses::Attribute::UNDERLINE) if pc == @vm.pc
          win.attroff(NCurses::Attribute::BOLD) if cursor_index == @cursor
          
          locs.try &.each_with_index do |loc, source_index|
            break if source_index + index >= h - 2
            cursor_loc << loc if cursor_index == @cursor
            win.attron(NCurses::Attribute::BOLD) if cursor_index == @cursor
            win.mvaddstr(loc.source, x: 30, y: 1 + index + source_index)
            win.attroff(NCurses::Attribute::BOLD) if cursor_index == @cursor
          end

          cursor_index += 1
          real_index += 1
          index += size
        end
        win.attron(NCurses::Attribute::REVERSE)
        win.mvaddstr("#{@vm.halted ? "Halted" : "Paused"} s:step c:continue q:quit b:break".ljust(w - 2, ' '), x: 1, y: 1 + h - 1)          

        file = cursor_loc.first?.try &.file || "???"
        line = cursor_loc.first?.try &.line || "???"
        win.mvaddstr("Unit #{file || "???"}:L#{line || "??"}".ljust(w - 2, ' '), x: 1, y: 1 + h - 2)
        win.attroff(NCurses::Attribute::REVERSE)
        win.refresh
      end      
    end

    def registers
      NCurses::Window.subwin x: (NCurses.maxx / 2).ceil, y: 0, height: (NCurses.maxy / 2).floor, width: NCurses.maxx / 6, parent: NCurses.stdscr do |w|
        w.border
        w.mvaddstr("PC: 0x#{@vm.pc.to_s(base:16).rjust(4, '0')}", x: 1, y: 1)
        @vm.registers.each_with_index do |r, i|
          w.mvaddstr("R#{i}: 0x#{r.to_s(base:16).rjust(4, '0')}", x: 1, y: 2 + i)
        end
        w.refresh
      end
    end

    def stack
      NCurses::Window.subwin x: (NCurses.maxx / 6 * 4).ceil, y: 0, height: (NCurses.maxy / 2).floor, width: NCurses.maxx / 3, parent: NCurses.stdscr do |stack|
        stack.border
        i = 0
        ((@spec.stack_start - stack.maxy + 3)..(@spec.stack_start)).each do |address|
          value = @vm.ram[address]
          stack.mvaddstr("STACK 0x#{address.to_s(base:16).rjust(4, '0')}: 0x#{value.to_s(base:16).rjust(4, '0')}", x: 1, y: 1 + i)
          i += 1
        end
        stack.refresh
      end
    end

    def io
      NCurses::Window.subwin x: (NCurses.maxx / 2).ceil, y: (NCurses.maxy / 2).floor, height: (NCurses.maxy / 2).ceil, width: NCurses.maxx / 2, parent: NCurses.stdscr do |io|
        io.border
        @output.rewind
        text = @output.gets_to_end
        io.mvaddstr(text, x: 1, y: 1)
        io.refresh
      end
    end    
  end  
end
