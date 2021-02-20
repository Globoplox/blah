require "./vm"
require "ncurses"

module RiSC16

  class Debugger

    @unit : Assembler::Unit
    @vm : VM
    
    def initialize(@unit, io)
      @vm = VM.new.tap &.load io
    end

    def run
      NCurses.open do
        NCurses.cbreak
        NCurses.noecho
        NCurses.keypad true
        NCurses.notimeout true
        
        code
        registers
        
        NCurses::Window.subwin x: (NCurses.maxx / 2).ceil, y: (NCurses.maxy / 2).floor, height: (NCurses.maxy / 2).ceil, width: NCurses.maxx / 2, parent: NCurses.stdscr do |idk|
          idk.border
          idk.mvaddstr("Press any key!", x: 1, y: 1)
          idk.mvaddstr("I'm a subwindow", x: 1, y: 2)
          idk.refresh
        end

        NCurses.getch
        NCurses.notimeout(true)
      end

      
    end

    def code
      h = NCurses.maxy 
      NCurses::Window.subwin x: 0, y: 0, height: h, width: (NCurses.maxx / 2).floor, parent: NCurses.stdscr do |w|
        w.border
        (0...(h-2)).each do |index|
          pc = index + @vm.pc
          next if pc < 0 || pc >= @vm.ram.size
          w.mvaddstr("0x#{pc.to_s(base:16).rjust(4, '0')}: 0b#{@vm.ram[pc].to_s(base:2).rjust(16, '0')}", x: 1, y: 1 + index)
        end
        w.refresh
      end      
    end

    def registers
      NCurses::Window.subwin x: (NCurses.maxx / 2).ceil, y: 0, height: (NCurses.maxy / 2).floor, width: NCurses.maxx / 2, parent: NCurses.stdscr do |w|
        w.border
        w.mvaddstr("PC: 0x#{@vm.pc.to_s(base:16).rjust(4, '0')}", x: 1, y: 1)
        @vm.registers.each_with_index do |r, i|
          w.mvaddstr("R#{i}: 0x#{r.to_s(base:16).rjust(4, '0')}", x: 1, y: 2 + i)
        end
        w.refresh
      end
      
    end
      
    
  end
  
end
