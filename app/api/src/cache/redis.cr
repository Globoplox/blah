require "redis"
require "./cache"

class Cache::Redis < Cache
  def self.from_environnment
    new ::Redis::PooledClient.new(
      host: ENV["REDIS_HOST"],
      port: ENV["REDIS_PORT"].to_i,
      database: ENV["REDIS_DB"].to_i,
      password: ENV["REDIS_PASSWORD"],
      pool_size: ENV["REDIS_POOL_SIZE"]?.try(&.to_i) || 20,
      pool_timeout: 1.seconds.total_seconds
    )
  end

  def initialize(@redis : ::Redis::PooledClient)
  end

  def set(key : String, value : String)
    @redis.set key, value
  end

  def get(key : String) : String?
    @redis.get key
  end

  def unset(key : String)
    @redis.del key
  end

  def close
  end
end