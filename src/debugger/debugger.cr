require "../vm"
require "../spec"
require "./curses"

# multi column output
# address, (if pseudo/data: source, if not first instruction in pseudo, then //.), instruction (source or disassembled, if data the word as it is), (compressed previous and current comments)
# we show all the same address LOC in another window (to complete the compressed)
# ex: 0x0000 | start | movi r1 :truc_machin | lui r1 0x????     | # this is a movi instr....
# ex: 0x0001 |       |                 ---  | addi r1 r1 0x???? | ---
#
# another window:
# This is a movi instruction. It load the upper part, then
# add the lower part
module RiSC16

  class Debugger

    @unit : Assembler::Unit
    @input = IO::Memory.new
    @output = IO::Memory.new
    @vm : VM
    @locs : Hash(UInt16, Array(Assembler::Loc))
    @cursor = 0
    @spec : Spec
    @breakpoints = [] of Int32
    
    def initialize(@unit, io, @spec)
      @vm = VM.from_spec(@spec, io_override: {"tty" => VM::MMIO.new(@input, @output)}).tap &.load io      
      @locs = {} of UInt16 => Array(Assembler::Loc)
      unit.each_with_address do |address, loc|
        (@locs[address] = @locs[address]? || [] of Assembler::Loc).push loc
      end
    end

    def disassemble(word)
      i = Instruction.decode word
      case i.opcode
      in ISA::Add, ISA::Nand
        if i.opcode.add? && i.reg_a == 0 && i.reg_b == 0 && i.reg_c == 0
          "nop"
        else
          "#{i.opcode} r#{i.reg_a} r#{i.reg_b} r#{i.reg_c}"
        end
      in ISA::Addi, ISA::Sw, ISA::Lw, ISA::Beq, ISA::Jalr
        if i.opcode.jalr? && i.immediate
          "halt 0x#{i.immediate.to_w}"
        else
          "#{i.opcode} r#{i.reg_a} r#{i.reg_b} 0x#{i.immediate.to_w}"
        end
      in ISA::Lui then "#{i.opcode} r#{i.reg_a} 0x#{i.immediate.to_w}"
      end
    end

    def run
      NCurses.open do
        NCurses.cbreak
        NCurses.noecho
        NCurses.keypad true
        NCurses.notimeout true
        window_cursor = 0
        windows = [] of Window
        
        windows << Table.new x: 0, y: 0, height: NCurses.maxy / 2, width: NCurses.maxx // 2, columns: [7, 20, 30], title: "CODE", range: (0..((@spec.ram_start + @spec.ram_size).to_i)) do |line|
          labels = (@locs[line]?.try(&.map &.label).try &.compact.join ", ") || " "
          dis = disassemble @vm.ram[line]
          ["0x#{line.to_u16.to_w}", dis, labels]
          #"0x#{line.to_u16.to_w}: #{labels.ljust(20, ' ')} #{dis}"
        end

        # windows << Scroll.new x: 0, y: (NCurses.maxy / 2).floor, height: NCurses.maxy // 2, width: NCurses.maxx // 2, title: "SOURCE" do |line|
        # end
        
        windows << Scroll.new x: (NCurses.maxx / 2).ceil, y: 0, height: (NCurses.maxy / 8).floor, width: NCurses.maxx // 6, range: 0..3, title: "REGISTERS" do |line|
          case line
          when 0 then "PC: 0x#{@vm.pc.to_w} R1: 0x#{@vm.registers[1].to_w}"
          when .in? 1..3 then "R#{line * 2}: 0x#{@vm.registers[line * 2].to_w} R#{line * 2 +1}: 0x#{@vm.registers[line * 2 + 1].to_w}" 
          end
        end
        
        windows << Scroll.new(
          x: (NCurses.maxx / 6 * 4).ceil, y: 0, height: (NCurses.maxy / 2).floor, width: NCurses.maxx // 3,
          range: ((@spec.ram_start.to_i)..(@spec.stack_start.to_i)), title: "STACK") do |line|
          "0x#{line.to_u16.to_w}: 0x#{@vm.ram[line].to_w}"
        end.tap(&.scroll_end)
        
        windows << CustomWindow.new x: (NCurses.maxx / 2).ceil, y: (NCurses.maxy / 2).floor, height: (NCurses.maxy / 2).ceil, width: NCurses.maxx // 2, title: "TTY" do |window|
          window.mvaddstr(@output.tap(&.rewind).gets_to_end, x: 1, y: 1)
        end

        windows.first.focus = true
        loop do
          windows.each &.draw
          case NCurses.getch
          when 'q', NCurses::KeyCode::ESC then break
          when 's' then @vm.step
          when 'b' then nil
          when 'c'
            loop do
              @vm.step
              break if @vm.halted
            end
            
          when NCurses::KeyCode::LEFT
            window_cursor = (window_cursor - 1) % windows.size
            windows.each_with_index { |window, index| window.focus = index == window_cursor }
          when NCurses::KeyCode::RIGHT
            window_cursor = (window_cursor + 1) % windows.size
            windows.each_with_index { |window, index| window.focus = index == window_cursor }
          when NCurses::KeyCode::UP then windows[window_cursor].up
          when NCurses::KeyCode::DOWN then windows[window_cursor].down
          end

          NCurses.clear
        end
      end
    end

    def code(win)
      w = NCurses.maxx // 2
      h = NCurses.maxy - 2
      cursor_loc = [] of Assembler::Loc
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
    end
    
  end  
end
