before_all "/foo" do |env|
  env.response.content_type = "application/json"
end

get "/" do
  {message: "Hello World!"}.to_json
end