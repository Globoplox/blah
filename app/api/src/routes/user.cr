post "/register" do |env|
  name = env.params.json["name"].as(String)
  email = env.params.json["email"].as(String)
  password = env.params.json["password"].as(String)

  session_id = APP.open_session_from_credentials(password: password, email: email)
  if session_id
    env.response.cookies << HTTP::Cookie.new(
      name: "__Host-session",
      value: session_id,
      secure: true,
      http_only: true,
      samesite: :strict
    )
  end
end

put "/login" do |env|
  email = env.params.json["email"].as(String)
  password = env.params.json["password"].as(String)

  session_id = APP.open_session_from_credentials(password: password, email: email)
  if session_id
    env.response.cookies << HTTP::Cookie.new(
      name: "__Host-session",
      value: session_id,
      secure: true,
      http_only: true,
      samesite: :strict
    )
  end
end

get "/self" do |env|
  session_id = env.request.cookies["__Host-session"]?.try &.value
  if session_id
    APP.get_self(session_id).to_json
  end
end 

delete "/disconnect" do |env|
  session_id = env.request.cookies["__Host-session"]?.try &.valu  
  if session_id
    APP.close_session(session_id)
  end
end 