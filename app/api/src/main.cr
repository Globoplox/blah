require "log"
require "db"
require "pg" # Load the PGSQL driver
require "./storage/s3"
require "./cache/redis"
require "./pubsub/redis"
require "./schema"
require "./repositories/*"
require "./api"

at_exit do |code, ex|
  pp "=========================== EXITED"
  pp code
  pp ex
  raise Exception.new "I wanna see the stacktrace"
rescue ex
  pp ex
end

Signal::INT.trap do
  pp "============================ INT!!"
end

# Setup all dependencies with a suitable implementation

storage = Storage::S3.from_environnment ENV["BUCKET"]
# Both cache and pubsub may use the same redis server, but they need separate client instance
cache = Cache::Redis.from_environnment
pubsub = PubSub::Redis.from_environnment

# Standard library database implementation is already an interface and factory for itself based on uri
# and loaded drivers.
database = DB.open ENV["DB_URI"]

# Run migrations if any
Schema.migrate database, schema: "main"

# Back to dependencies
users = Repositories::Users::Database.new database
projects = Repositories::Projects::Database.new database
notifications = Repositories::Notifications::PubSub.new pubsub
files = Repositories::Files::Database.new database
blobs = Repositories::Blobs::Database.new database

# NOTE that binding must be explicitely using tcp or tls to enable port reuse for horizontal scaling purposes
bind = ENV["BIND_URI"]
cors_origin = ENV["CLIENT_ORIGIN"]

Api.new(
  storage: storage,
  cache: cache,
  users: users,
  projects: projects,
  files: files,
  blobs: blobs,
  notifications: notifications,
  bind: bind,
  cors_origin: cors_origin
).tap do |api|
  Signal::TERM.trap do
    Log.info &.emit "Received sigterm, gracefully shutting down"
    api.close
    database.close
    storage.close
    cache.close
    Log.info &.emit "Shutting down"
  end
end.start
