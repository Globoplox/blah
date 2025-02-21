# Interface for storage implementation.
# Storage is expected to be persistent.
abstract class Storage

  enum ACL
    Public
    Private
  end

  # This method is expetced to return a WEB URL allowing access to a given ressource.
  abstract def uri(name : String, public : Bool = false, internal : Bool = false) : String

  abstract def put(data : Bytes | IO | String, mime : String, name : String, acl : ACL = :private)

  abstract def delete(name : String)

  abstract def batch_delete(names : Indexable(String))

  abstract def close
end
