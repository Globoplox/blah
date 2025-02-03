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
        raise Error::BadContentType.new
      end
      body.from_json @request.body || raise Error::MissingBody.new
    end

    def <<(obj)
      case obj
      when Error then @response.status = obj.http_status
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
