# class Blob
#   alias ID = UUID

#   property id : ID
#   property content_type : String
#   property size : UInt32
#   property created_at : Time
# end

# class Credentials
#   alias ID = UUID

#   property id : ID
#   property email : String
#   property password_hash : String
# end

# class User
#   alias ID = UUID

#   def self.validate_name(name : String) : String
#     name
#   end
  
#   property id : ID
#   property name : String
#   property tag : String
#   property avatar_id : Blob::ID?
#   property allowed_blob_size : UInt32
#   property allowed_project : UInt32
#   property allowed_concurrent_job : UInt32
#   property allowed_concurrent_tty : UInt32
#   property created_at : Time
# end

# class Project
#   alias ID = UUID

#   property id : ID
#   property name : String
#   property description : String
#   property public : Bool
#   property owner_id : User::ID
#   property avatar_id : Blob::ID?
#   property allowed_blob_size : UInt32
#   property allowed_file_amount : UInt32
#   property created_at : Time
# end

# class File
#   alias ID = UUID

#   property id : ID
#   property project_id : Project::ID
#   property blob_id : Blob::ID
#   property path : String
#   property author_id : User::ID
#   property editor_id : User::ID
#   property edited_at : Time
#   property created_at : Time
# end