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

  def setnx(key : String, value : String)
    @redis.setnx key, value
  end

  def incr(key) : Int64
    @redis.incr key
  end

  def decr(key) : Int64
    @redis.decr key
  end

  def get(key : String) : String?
    @redis.get key
  end

  def unset(key : String)
    @redis.del key
  end

  def expire(key : String, timeout : Time::Span)
    @redis.expire key, timeout.total_seconds.to_i
  end

  def close
  end
end