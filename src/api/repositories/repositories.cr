# Interfaces for repositories.
module Repositories

  module Cancelable
    def cancel
    end
  end

  abstract class Users

    class DuplicateNameError
    end

    class DuplicateIdentifierError
    end

    abstract def insert(
      identifier : String,
      password_hash : String,
      name : String,
      allowed_projects : Int32,
      allowed_blob_size : Int32,
      allowed_concurrent_job : Int32,
    ) : UUID | DuplicateNameError | DuplicateIdentifierError

    class UserWithCredentials
      include DB::Serializable
      property id : UUID
      property name : String
      property allowed_blob_size : Int32
      property allowed_project : Int32
      property allowed_concurrent_job : Int32
      property created_at : Time
      property credential_id : UUID
      property identifier : String
      property password_hash : String
    end

    abstract def get_by_identifier_with_credentials(identifier : String) : UserWithCredentials?

    class User
      include DB::Serializable
      property id : UUID
      property name : String
      property avatar_blob_id : UUID?
      property allowed_blob_size : Int32
      property allowed_project : Int32
      property allowed_concurrent_job : Int32
      property created_at : Time
    end

    abstract def read(id : UUID) : User
    abstract def get_by_name(name : String) : User?
    abstract def set_avatar(user_id : UUID, blob_id : UUID?)
  end

  abstract class Projects
    
    class DuplicateNameError
    end

    abstract def insert(
      name : String,
      owner_id : UUID,
      public : Bool,
      description : String?,
      allowed_blob_size : UInt32,
      allowed_file_amount : UInt32
    ) : UUID | DuplicateNameError
  
    class Project
      include DB::Serializable
      property id : UUID
      property name : String
      property owner_id : UUID
      property public : Bool
      property description : String?
      property allowed_blob_size : Int32
      property allowed_file_amount : Int32
      property created_at : Time
      property owner_name : String
      property avatar_blob_id : UUID?
    end

    class Acl
      include DB::Serializable
      property user_id : UUID
      property user_name : String
      property can_write : Bool
      property can_read : Bool
      property avatar_blob_id : UUID?
    end

    abstract def search_public(query  : String?) : Array(Project)
    abstract def search_owned(owner_id : UUID, query  : String?) : Array(Project)
    abstract def read(id  : UUID) : Project
    abstract def get_by_user_and_name(user_id : UUID, name : String) : Project?
    abstract def count_for_user(user_id : UUID) : Int64
    abstract def user_can_rw(project_id : UUID, user_id : UUID) : {Bool, Bool}
    abstract def acl(project_id : UUID, query : String? = nil) : Array(Acl)
    abstract def set_acl(project_id : UUID, user_id : UUID, can_read : Bool, can_write : Bool)
    abstract def set_avatar(project_id : UUID, blob_id : UUID?)
  end

  abstract class Blobs
    abstract def insert(content_type : String, size : Int32) : UUID
    abstract def delete(blob_id : UUID,)
    abstract def update(blob_id : UUID, size : Int32)
  end

  abstract class Files

    class DuplicatePathError
    end

    class File
      include DB::Serializable
      property project_id : UUID
      property path : String
      property author_id : UUID
      property editor_id : UUID
      property blob_id : UUID?
      property created_at : Time
      property file_edited_at : Time
      property author_name : String
      property editor_name : String
      property is_directory : Bool
      property size : Int32 = 0
    end

    abstract def insert(project_id : UUID, blob_id : UUID?, path : String, author_id : UUID) : DuplicatePathError?
    abstract def delete(project_id : UUID, path : String)
    abstract def move(project_id : UUID, path : String, to_path : String, editor_id : UUID) : DuplicatePathError?
    abstract def edit(project_id : UUID, path : String, editor_id : UUID)
    abstract def list(project_id : UUID) : Array(File)
    abstract def get_blob_id(project_id : UUID, path : String) : UUID?
    abstract def is_directory?(project_id : UUID, path : String) : Bool
    abstract def read(project_id : UUID, path : String) : File?
    abstract def sum_for_user(user_id : UUID) : Int64
    abstract def sum_for_project(project_id : UUID) : Int64
    abstract def count_for_project(project_id : UUID) : Int64
  end

  abstract class Notifications
    abstract def create_file(project_id : UUID, path : String)
    abstract def delete_file(project_id : UUID, path : String)
    abstract def move_file(project_id : UUID, old_path : String, new_path : String)
    abstract def on_file_created(project_id : UUID, handler : (String) ->) : Cancelable
    abstract def on_file_deleted(project_id : UUID, handler : (String) ->)  : Cancelable
    abstract def on_file_moved(project_id : UUID, handler : (String, String) ->) : Cancelable
  end
end