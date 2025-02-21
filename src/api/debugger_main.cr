# Entrypoint for launching a debugger within an APPlication filesystem
require "log"
require "db"
require "pg"
require "shimfs"
require "./storage/s3"
require "./cache/redis"
require "./pubsub/redis"
require "./repositories/*"
require "../toolchain"
require "../toolchain/io_event_stream"
require "./app_filesystem"

spec_path = ARGV[0]
source = ARGV[1]
symbols = ARGV[2]
project_id = UUID.new ARGV[3]
user_id = UUID.new ARGV[4]
macros = {} of String => String

shimfs_name = ARGV[5]
shimfs_size = ARGV[6].to_i
shimfs_address = Pointer(Void).new ARGV[7].to_u64

ARGV[8...].each do |macro_def|
  key, value = macro_def.split '='
  macros[key] = value
end

shimfs = Shimfs.new shimfs_size, shimfs_name, shimfs_address

storage = Storage::S3.from_environnment ENV["BUCKET"]
cache = Cache::Redis.from_environnment no_pool: true
pubsub = PubSub::Redis.from_environnment
database = DB.open ENV["DB_URI"]
users = Repositories::Users::Database.new database
projects = Repositories::Projects::Database.new database
notifications = Repositories::Notifications::PubSub.new pubsub
files = Repositories::Files::Database.new database
blobs = Repositories::Blobs::Database.new database

es = Toolchain::IOEventStream.new STDERR
fs = Toolchain::AppFilesystem.new storage, users, projects, files, blobs, notifications, project_id, user_id, es, shimfs
toolchain = Toolchain.new false, spec_path, macros, fs, es
io_mapping = {} of String => {IO, IO}

toolchain.spec.segments.each do |segment|
  case segment
  when RiSC16::Spec::Segment::IO
    name = segment.name
    if name && segment.tty && segment.source.nil?
      io_mapping[name] = {IO::Memory.new, IO::Memory.new}
    end
  end
end

symbols = nil if symbols.empty?
toolchain.debug(source, symbols, STDIN, STDOUT, io_mapping)
