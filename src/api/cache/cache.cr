# Interface for cache implementation.
# Cache are expected to be fast key value store.
# Cache does not requires long term persistence.
abstract class Cache
  
  abstract def set(key : String, value : String)

  abstract def incr(key) : Int64

  abstract def decr(key) : Int64
  
  abstract def setnx(key : String, value : String) : Bool

  abstract def get(key : String) : String?

  abstract def unset(key : String)

  abstract def expire(key : String, timeout : Time::Span)

  abstract def close

end