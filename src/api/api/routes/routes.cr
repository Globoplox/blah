class Api
  class Response::ID
    include JSON::Serializable
    property id : UUID
    def initialize(@id)
    end
  end
end