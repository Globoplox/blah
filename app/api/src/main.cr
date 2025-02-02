require "log"
require "kemal"
require "./schema"
require "./cache"
require "./storage"
require "./app"

Schema.init
Storage.init
Cache.init

APP = App.new schema: Schema, storage: Storage, cache: Cache

require "./routes/*"

Signal::TERM.trap { Kemal.stop }

Kemal.run do |config|
  config.server.not_nil!.bind ENV["BIND_URI"]
end

# Remind the skill you want to show off:
# dback: docker, compose, git, sql, nice auth, oauth, redis, pubsub, loadbalancing, scaling, clean code arch, dependency injection, TESTING
# front: you can do react