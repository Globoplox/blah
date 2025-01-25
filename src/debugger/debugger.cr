require "../vm"
require "../spec"
require "./curses"
require "../linker/linker"

# NOTE: this is broken because reading the ram from vm cause IO side effects.

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
    # @units : Array(Assembler::Unit)
    @input = IO::Memory.new
    @output = IO::Memory.new
    @vm : VM
    # @locs : Hash(UInt16, Array(Assembler::Loc))
    @cursor = 0
    @spec : Spec
    @breakpoints = Set(Int32).new
    @object : RiSC16::Object? = nil
    @definitions : Hash(UInt16, {String, Char})
    @references : Hash(UInt16, String)

    def initialize(io, @spec, @object = nil, at = 0)
      @section_stack_symbol_value = 0

      Linker.symbols_from_spec(@spec).each do |(name, symbol)|
        if name == "__section_stack"
          @section_stack_symbol_value = symbol.address
        end
      end

      @vm = VM.from_spec(@spec, io_override: {"tty" => {@input, @output}}).tap &.load io, at: at
      @references = {} of UInt16 => String
      @object.try do |object|
        object.sections.each do |section|
          section.references.each do |(name, locations)|
            locations.each do |location|
              local_name = name#.gsub("__function_", "").gsub("__global_", "")
               if location.offset != 0
                 if location.offset > 0
                   local_name += "+" 
                 end
                 local_name += "#{location.offset}"
               end
              @references[location.address + section.absolute.not_nil!] = local_name # assuming we are debugging a binary loaded at 0
            end
          end
        end
      end
      @definitions = @object.try do |object|
        object.sections.flat_map do |section|
          section.definitions.to_a.map do |(name, symbol)|
            char = 's'
            if name.starts_with? "__function_"
              char = 'f'
              name = name.gsub("__function_", "")
            elsif name.starts_with? "__global_"
              char = 'g'
              name = name.gsub("__global_", "")
            end
            if symbol.exported
              char = char.upcase
            end
            {(symbol.address + section.absolute.not_nil!).to_u16, {name, char}}
          end
        end.to_h
      end || {} of UInt16 => {String, Char}
    end

    def disassemble(word, address)
      i = Instruction.decode word
      imm_repr = @references[address]? || "0x#{i.immediate.to_w}"
      case i.opcode
      in ISA::Add, ISA::Nand
        if i == 0u16
          "nop"
        else
          "#{i.opcode} r#{i.reg_a} r#{i.reg_b} r#{i.reg_c}"
        end
      in ISA::Addi, ISA::Sw, ISA::Lw, ISA::Beq, ISA::Jalr
        if i.opcode.jalr? && i.immediate != 0
          "halt 0x#{imm_repr}"
        else
          "#{i.opcode} r#{i.reg_a} r#{i.reg_b} #{imm_repr}"
        end
      in ISA::Lui then "#{i.opcode} r#{i.reg_a} #{imm_repr}"
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

        rem = (NCurses.maxx // 2) - (8 + 3 + 20 + 3 + 2 + 8 + 1)
        code = Table.new(
          x: 0, y: 0,
          height: NCurses.maxy, width: NCurses.maxx // 2,
          columns: [8, 3, 20, 8, rem], title: "CODE",
          range: (0..((UInt16::MAX).to_i))
        ) do |address|
          word = @vm.read address.to_u16
          dis = disassemble word, address
          dis = dis.ljust rem - 2
          symbol = @definitions[address]?
          kind = symbol.try &.[1] || ' '
          symbol = symbol.try &.[0] || ""
          symbol = symbol.ljust(18)
          symbol = "#{symbol[0...15]}..." if symbol.size > 18
          cursor = case {@breakpoints.includes?(address), address}
                   when {_, @vm.pc} then ">"
                   when {true, _}   then "@"
                   else                  "#{kind}"
                   end
          ["0x#{address.to_u16.to_w}", cursor, symbol, "0x#{word.to_s(base: 16)}", dis]
        end
        windows << code

        # windows << Scroll.new x: 0, y: (NCurses.maxy / 2).floor, height: NCurses.maxy // 2, width: NCurses.maxx // 2, title: "SOURCE" do |line|
        # end

        windows << Scroll.new x: (NCurses.maxx / 2).ceil, y: 0, height: 10, width: NCurses.maxx // 6, range: 0..7, title: "REGISTERS" do |line|
          case line
          when 0         then "PC: 0x#{@vm.pc.to_w}"
          else "R#{line}: 0x#{@vm.registers[line].to_w}"
          end
        end

        windows << Table.new(
          x: (NCurses.maxx / 6 * 4).ceil, y: 0, height: (NCurses.maxy).floor, width: NCurses.maxx // 6,
          columns: [3, 16], range: ((0)..(UInt16::MAX.to_i)), title: "STACK") do |address|
          [(address == @vm.registers[7] ? ">" : " "),"0x#{address.to_u16.to_w}: 0x#{@vm.read_noio(address.to_u16).try(&.to_w) || "?IO?"}"]
        end.tap(&.center @section_stack_symbol_value)

        #windows << CustomWindow.new x: (NCurses.maxx / 2).ceil, y: (NCurses.maxy / 2).floor, height: (NCurses.maxy / 2).ceil, width: NCurses.maxx // 2, title: "TTY" do |window|
        #  window.mvaddstr(@output.tap(&.rewind).gets_to_end, x: 1, y: 1)
        #end

        windows.first.focus = true
        loop do
          windows.each &.draw
          case NCurses.getch
          when 'q', NCurses::KeyCode::ESC then break
          when 's'                        then @vm.step
          when 'b' then if @breakpoints.includes? code.cursor
            @breakpoints.delete code.cursor
          else
            @breakpoints.add code.cursor
          end
          when 'c'
            loop do
              @vm.step
              break if @vm.halted || @breakpoints.includes? @vm.pc
            end
          when NCurses::KeyCode::LEFT
            window_cursor = (window_cursor - 1) % windows.size
            windows.each_with_index { |window, index| window.focus = index == window_cursor }
          when NCurses::KeyCode::RIGHT
            window_cursor = (window_cursor + 1) % windows.size
            windows.each_with_index { |window, index| window.focus = index == window_cursor }
          when NCurses::KeyCode::UP   then windows[window_cursor].up
          when NCurses::KeyCode::DOWN then windows[window_cursor].down
          end

          NCurses.clear
        end
      end
    end
  end
end
