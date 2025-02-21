lib LibNCurses
  type File = Void

  fun dup(fd : LibC::Int) : LibC::Int
  fun fdopen(fd : LibC::Int, mode : LibC::Char*) : File*
  fun fclose(stream : File*)
  fun newterm(unamed : LibC::Char*, in : File*, out : File*) : Screen
  fun set_term(screen :  Screen) : Screen

  $stdscr : Window
end

module NCurses

  def open(stdin : IO::FileDescriptor, stdout : IO::FileDescriptor)
    infile = LibNCurses.fdopen(LibNCurses.dup(stdin.fd), "r")
    outfile = LibNCurses.fdopen(LibNCurses.dup(stdout.fd), "w")
    screen = LibNCurses.newterm("xterm-256color", outfile, infile)
    LibNCurses.set_term screen
    @@stdscr = Window.new(LibNCurses.stdscr)

    begin
      yield
    ensure
      LibNCurses.fclose(infile)
      LibNCurses.fclose(outfile)
      LibNCurses.endwin
    end
  end

end