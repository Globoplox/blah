# Interface for publish/subscribe implementation.
# It is intended for usage IPC between api's instances
abstract class PubSub
  abstract def publish(channel : String, message : String)
  abstract def subscribe(channel : String, handler : String ->) : Subscription

  abstract class Subscription
    abstract def unsubscribe
  end
end