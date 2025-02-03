require "http/server"
require "http/status"

class Api
  # Request context
  class Context
    property request : HTTP::Request
    property response : HTTP::Server::Response
    property path_parameters : Hash(String, String)?

    delegate :status, :status=, to: @response

    def >>(body : Type.class) : Type forall Type
      unless @request.headers["Content-Type"]? == "application/json"
        raise Error.new HTTP::Status::UNSUPPORTED_MEDIA_TYPE, "UnsupportedMediaType", "Expected application/json body"
      end
      body.from_json @request.body || raise Error.new HTTP::Status::BAD_REQUEST, "BadRequest", "No body in request, expected a #{body}"
    end

    def <<(obj)
      case obj
      when Error then @response.status = obj.code
      end
      @response.content_type = "application/json"
      obj.to_json @response
    end

    def path_parameter(name)
      path_parameters.not_nil![name]
    end

    def initialize(ctx : HTTP::Server::Context)
      @request = ctx.request
      @response = ctx.response
    end
  end
end
