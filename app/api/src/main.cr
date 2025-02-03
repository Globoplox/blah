require "log"
require "db"
require "pg" # Load the PGSQL driver

require "./storage/s3"
require "./cache/redis"
require "./schema"
require "./repositories/*"
require "./api"

# Setup all dependencies with a suitable implementation
storage = Storage::S3.from_environnment ENV["BUCKET"]
cache = Cache::Redis.from_environnment

# Standard library database implementation is already an interface and factory for itself based on uri
# and loaded drivers.
database = DB.open ENV["DB_URI"]

# Run migrations if any
Schema.migrate database, schema: "main"

# Back to dependencies
users = Repositories::Users::Database.new database

# NOTE that vinding must be explicitely using tcp or tls to enable port reuse for horizontal scaling purposes
bind = ENV["BIND_URI"]

Api.new(
  storage: storage,
  cache: cache,
  users: users,
  bind: bind
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
