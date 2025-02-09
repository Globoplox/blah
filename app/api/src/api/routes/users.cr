require "crypto/bcrypt"

class Api

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
      allowed_concurrent_job: 1,
      allowed_concurrent_tty: 10
    )

    case user_id
    when Repositories::Users::DuplicateNameError
      raise Error.bad_parameter "name", "a users with the same name already exists"
    when Repositories::Users::DuplicateEmailError
      raise Error.bad_parameter "email", "a users with the same email already exists"
    end

    session_id = open_session(user_id)
    set_session_cookie(ctx, session_id, registration.stay_signed)

    ctx.response.status = HTTP::Status::CREATED
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
    
    pp user_and_credentials.password_hash

    unless Crypto::Bcrypt::Password.new(user_and_credentials.password_hash).verify(login.password)
      raise Error::InvalidCredential.new
    end
    
    session_id = open_session(user_and_credentials.id)
    set_session_cookie(ctx, session_id, login.stay_signed)
    ctx.response.status = HTTP::Status::CREATED
  end

  route GET, "/self", def get_self(ctx)
    user_id = authenticate(ctx)
  end

  route DELETE, "/disconnect", def disconnect(ctx)
    session_id = get_session_cookie(ctx)
    close_session(session_id) if session_id
    remove_session_cookie(ctx)
    ctx.response.status = HTTP::Status::NO_CONTENT
  end

end
