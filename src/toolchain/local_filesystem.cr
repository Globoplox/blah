require "option_parser"
require "colorize"
require "./toolchain"
require "./debugger"

# Implement a toolchain filesystem provider that wrap the local filesystem.
# Notably used by the command line interface client
class Toolchain::LocalFilesystem < Toolchain::Filesystem
  
  def normalize(path : String) : String
    Path[path].relative_to("./").to_s
  end

  def absolute(path : String, root = nil) : String
    if root
      Path[path].expand(home:true, base: root).to_s
    else
      Path[path].expand(home:true).to_s
    end
  end
  
  def open(path : String, mode : String) : IO
    File.open path, mode
  end
  
  def read(path : String, block)
    File.open path, "r" do |io|
      block.call io
    end
  end
  
  def write(path : String, block)
    File.open path, "w" do |io| 
      block.call io
    end
  end
  
  def directory?(path : String) : Bool
    File.directory? path
  end
  
  def base(path : String) : {String, String?, String?} # directory, base name, extension
    dir = File.dirname(path) || "."
    ext = File.extname path
    base = File.basename path, ext
    base = nil if base.empty?
    ext = nil if ext.empty?
    {dir, base, ext}
  end
  
  def path_for(directory : String, basename : String?, extension : String?)
    basename = "#{basename}#{extension}" if basename && extension
    Path[(directory || "."), basename].to_s
  end
end