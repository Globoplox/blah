require "redis"
require "./pubsub"

# The subscriber client is locked into this mode.
# Thus we need a separate client for publication.
class PubSub::Redis < PubSub
  def self.from_environnment
    new ::Redis.new(
      host: ENV["REDIS_HOST"],
      port: ENV["REDIS_PORT"].to_i,
      database: ENV["REDIS_DB"].to_i,
      password: ENV["REDIS_PASSWORD"]
    ), ::Redis.new(
      host: ENV["REDIS_HOST"],
      port: ENV["REDIS_PORT"].to_i,
      database: ENV["REDIS_DB"].to_i,
      password: ENV["REDIS_PASSWORD"]
    )
  end

  @subscriptions = {} of String => Array({Int32, ((String)->)})
  @fiber : Fiber
  @subscriber : ::Redis
  @publisher : ::Redis | ::Redis::PooledClient

  def initialize(@subscriber, @publisher)
    @id = 0
    @fiber = spawn do
      @subscriber.subscribe "root" do |subscription|
        subscription.message do |channel, message|
          @subscriptions[channel]?.try &.each &.[1].call message
        end
      end
    end
  end

  def publish(channel : String, message : String)
    @publisher.publish channel, message
  end

  class Subscription < PubSub::Subscription
    def initialize(@parent : PubSub::Redis, @channel : String, @id : Int32)
    end

    def unsubscribe
      @parent.unsubscribe(@channel, @id)
    end
  end

  def subscribe(channel : String, handler : String ->) : Subscription
    handlers = @subscriptions[channel]?

    unless handlers
      handlers = @subscriptions[channel] = [] of {Int32, (String)->}
    end

    id = (@id += 1)
    handlers.push({id, handler})

    @subscriber.subscribe(channel)

    return Subscription.new(self, channel, id)
  end

  def unsubscribe(channel, id)
    @subscriber.subscribe(channel)

    handlers = @subscriptions[channel]?
    
    if handlers
      handlers = handlers.reject(&.[0].== id)
      if handlers.empty?
        @subscriptions.delete channel
      else
        @subscriptions[channel] = handlers
      end
    end

  end

end