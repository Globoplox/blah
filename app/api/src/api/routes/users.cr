require "crypto/bcrypt"
require "pluto"
require "pluto/format/jpeg"
require "pluto/format/png"

class Api

  class User
    include JSON::Serializable
    property name : String
    property avatar_uri : String?
    property allowed_blob_size : Int32
    property allowed_project : Int32
    property allowed_concurrent_job : Int32
    property created_at : Time
    property id : UUID

    def initialize(@name, @avatar_uri, @allowed_blob_size, @allowed_project, @allowed_concurrent_job, @created_at, @id)
    end
  end

  def authenticate(ctx) : UUID
    session_id = get_session_cookie(ctx)
    raise Error::Auth.new "Not authenticated" unless session_id
    user_id = get_session(session_id)
    raise Error::Auth.new "Not authenticated" unless user_id
    user_id
  end

  alias SessionID = UUID

  def open_session(user_id : UUID) : SessionID
    session_id = UUID.random
    @cache.set "session:#{session_id}", user_id.to_s
    @cache.expire "session:#{session_id}", 8.hours
    session_id
  end

  def close_session(session_id : SessionID)
    @cache.unset "session:#{session_id}"
  end

  def get_session(session_id : SessionID) : UUID?
    @cache.get("session:#{session_id}").try do |value|
      UUID.new value
    end
  end

  SESSION_COOKIE_NAME = "__Host-session"

  def set_session_cookie(ctx, session_id : SessionID, stay_signed : Bool)
    ctx.response.cookies << HTTP::Cookie.new(
      name: SESSION_COOKIE_NAME,
      value: session_id.to_s,
      secure: true,
      http_only: true,
      samesite: HTTP::Cookie::SameSite::None,
      max_age: stay_signed.try { 8.hours }
    )
  end

  def remove_session_cookie(ctx)
    ctx.response.cookies << HTTP::Cookie.new(
      name: SESSION_COOKIE_NAME,
      value: "",
      secure: true,
      http_only: true,
      samesite: HTTP::Cookie::SameSite::None,
      max_age: Time::Span::ZERO
    )
  end

  def get_session_cookie(ctx) : SessionID?
    ctx.request.cookies[SESSION_COOKIE_NAME]?.try { |cookie| UUID.new cookie.value }
  end

  REGISTER_PASSWORD_BCRYPT_COST = Crypto::Bcrypt::DEFAULT_COST

  class Request::Registration
    include JSON::Serializable
    property email : String
    property password : String
    property name : String
    property stay_signed : Bool = false
  end

  route POST, "/register", def register(ctx)
    registration = ctx >> Request::Registration

    Validations.validate! do
      accumulate "email", check_email registration.email
      accumulate "password", check_password registration.password, email: registration.email, name: registration.name
      accumulate "name", check_username registration.name
    end

    user_id = @users.insert(
      email: registration.email,
      name: registration.name,
      password_hash: Crypto::Bcrypt::Password.create(
        registration.password,
        cost: REGISTER_PASSWORD_BCRYPT_COST
      ).to_s,
      tag: "0000", 
      allowed_projects: 5, 
      allowed_blob_size: 1_000_000, 
      allowed_concurrent_job: 1
    )

    case user_id
    when Repositories::Users::DuplicateNameError
      raise Error.bad_parameter "name", "a users with the same name already exists"
    when Repositories::Users::DuplicateEmailError
      raise Error.bad_parameter "email", "a users with the same email already exists"
    end

    session_id = open_session(user_id)
    set_session_cookie(ctx, session_id, registration.stay_signed)

    user = @users.read(user_id)
    ctx.response.status = HTTP::Status::CREATED
    ctx << User.new(
      name: user.name,
      avatar_uri: user.avatar_blob_id.try { |blob_id| @storage.uri(blob_id.to_s) },
      allowed_blob_size: user.allowed_blob_size,
      allowed_project: user.allowed_project,
      allowed_concurrent_job: user.allowed_concurrent_job,
      created_at: user.created_at,
      id: user_id
    )
  end

  class Request::Login
    include JSON::Serializable
    property email : String
    property password : String
    property stay_signed : Bool = false
  end

  route PUT, "/login", def login(ctx)
    login = ctx >> Request::Login

    user_and_credentials = @users.get_by_email_with_credentials(login.email)
    unless user_and_credentials
      raise Error::InvalidCredential.new
    end
    
    unless Crypto::Bcrypt::Password.new(user_and_credentials.password_hash).verify(login.password)
      raise Error::InvalidCredential.new
    end
    
    session_id = open_session(user_and_credentials.id)
    set_session_cookie(ctx, session_id, login.stay_signed)

    user = @users.read(user_and_credentials.id)
    ctx.response.status = HTTP::Status::CREATED
    ctx << User.new(
      name: user.name,
      avatar_uri: user.avatar_blob_id.try { |blob_id| @storage.uri(blob_id.to_s) },
      allowed_blob_size: user.allowed_blob_size,
      allowed_project: user.allowed_project,
      allowed_concurrent_job: user.allowed_concurrent_job,
      created_at: user.created_at,
      id: user_and_credentials.id
    )
  end

  route GET, "/self", def get_self(ctx)
    user_id = authenticate(ctx)
    user = @users.read(user_id)
    ctx.response.status = HTTP::Status::OK
    ctx << User.new(
      name: user.name,
      avatar_uri: user.avatar_blob_id.try { |blob_id| @storage.uri(blob_id.to_s) },
      allowed_blob_size: user.allowed_blob_size,
      allowed_project: user.allowed_project,
      allowed_concurrent_job: user.allowed_concurrent_job,
      created_at: user.created_at,
      id: user_id
    )
  end

  route DELETE, "/disconnect", def disconnect(ctx)
    session_id = get_session_cookie(ctx)
    close_session(session_id) if session_id
    remove_session_cookie(ctx)
    ctx.response.status = HTTP::Status::NO_CONTENT
  end

  AVATAR_EDGE_SIZE = 180

  route POST, "/users/self/avatar", def put_self_avatar(ctx)
    user_id = authenticate(ctx)

    case ctx.request.headers["content-type"]
    when "image/png"  then pic = Pluto::ImageRGBA.from_png ctx.request.body || raise Error::MissingBody.new
    when "image/jpeg" then pic = Pluto::ImageRGBA.from_jpeg ctx.request.body || raise Error::MissingBody.new
    else                   raise "unexpected picture format"
    end

    edge = Math.min pic.width, pic.height
    data = IO::Memory.new
    pic.crop!(
      (pic.width - edge) // 2,
      (pic.height - edge) // 2,
      edge,
      edge
    ).bilinear_resize!(AVATAR_EDGE_SIZE, AVATAR_EDGE_SIZE).to_png data
    data.rewind

    content_type = "image/png"
    size = data.size

    user = @users.read(user_id)

    user.avatar_blob_id.try do |existing|
      @blobs.delete(existing)
      @storage.delete(existing.to_s)
    end 
    
    blob_id = @blobs.insert(
      content_type: content_type,
      size: size
    )

    @storage.put(
      data: data, 
      mime: content_type, 
      name: blob_id.to_s,
      acl: Storage::ACL::Private
    )

    @users.set_avatar(user_id, blob_id)

    ctx << User.new(
      name: user.name,
      avatar_uri: user.avatar_blob_id.try { |blob_id| @storage.uri(blob_id.to_s) },
      allowed_blob_size: user.allowed_blob_size,
      allowed_project: user.allowed_project,
      allowed_concurrent_job: user.allowed_concurrent_job,
      created_at: user.created_at,
      id: user_id
    )

    ctx.response.status = HTTP::Status::CREATED
  end
end
