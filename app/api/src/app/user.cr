require "crypto/bcrypt"

class App

  REGISTER_PASSWORD_BCRYPT_COST = Crypto::Bcrypt::DEFAULT_COST

  alias SessionID = UUID

  def register_user(email, password, name) : SessionID?
    # Tape, should be handled with a database rotatin pseudo random
    tag_seed = Crystal::Hasher.new.tap { |hasher| 
      hasher.string name
      hasher.number Time.utc.to_unix
    }.result
    tag_random = Random.new tag_seed
    tag = (0...4).map { (0..9).map(&.to_s).sample tag_random }.join

    password_hash = Crypto::Bcrypt::Password.create(password, cost: REGISTER_PASSWORD_BCRYPT_COST).digest

    @schema.register_user_credentials(
      email: email,
      password_hash: password_hash,
      name: name,
      tag: tag,
      allowed_projects: 5,
      allowed_blob_size: 10_000_000,
      allowed_concurrent_job: 1,
      allowed_concurrent_tty: 10
    )
  end

  def open_session_from_credentials(email, password) : SessionID?
    user = @schema.get_user_by_credentials(email)

    if user
      if Crypto::Bcrypt::Password.new(user[:hash]).verify(password)
        session_id = UUID.random
        @cache.store "session:#{session_id}", user.to_json
        session_id
      end
    end
  end

  def close_session(session_id : SessionID)
    @cache.unset "session:#{session_id}"
  end

  def update_self(session_id : SessionID)
    raise NotImplementedError.new
  end

  def set_user_avatar()
    raise NotImplementedError.new
  end

  def remove_user_avatar()
    raise NotImplementedError.new
  end

  alias Self = {id: UUID, name: String, tag: String}

  def get_self(session_id : SessionID) : Self
    session = @cache.fetch "session:#{session_id}"
    if session
      session = JSON.parse session
      {
        id: UUID.parse(session["id"].as_s),
        name: UUID.parse(session["name"].as_s),
        tag: UUID.parse(session["tag"].as_s),
      }
    end
  end

  def update_user_password()
    raise NotImplementedError.new
  end

  def delete_user()
    raise NotImplementedError.new
  end

  def get_rgpd_summary()
    raise NotImplementedError.new
  end
end