class Exception
  @[JSON::Field(ignore: true)]
  @cause : Exception?
  @[JSON::Field(ignore: true)]
  @callstack : CallStack?
end

class Api
  class Error < Exception

    enum Code
      UNAUTHORIZED
      INVALID_CREDENTIALS
      BAD_REQUEST
      BAD_PARAMETER
      SERVER_ERROR
      NOT_FOUND
    end

    def self.status_for(code : Code) : HTTP::Status
      case code
      when Code::SERVER_ERROR then HTTP::Status::INTERNAL_SERVER_ERROR
      else HTTP::Status::UNPROCESSABLE_ENTITY
      end
    end

    include JSON::Serializable
    @[JSON::Field(ignore: true)]
    property http_status : HTTP::Status
    property code : Code
    property error : String
    property message : String?

    def initialize(@code, @error, @message = nil, @http_status = Error.status_for(code))
    end

    def self.validation(field, message)
      Error.new HTTP::Status::UNPROCESSABLE_ENTITY, field, message
    end

    class NotFound < Error
      def initialize(resource)
        super(:not_found, "Ressource not found", "The resource #{resource} was not found")
      end
    end

    class ServerError < Error
      def initialize(message)
        super(:server_error, "Server Error", (message if Api.debug))
      end
    end

    class InvalidCredential < Error
      def initialize
        super(:invalid_credentials, "Bad credentials")
      end
    end

    class Auth < Error
      def initialize(message)
        super(:unauthorized, "Unauthorized", message)
      end
    end

    class MissingBody < Error
      def initialize
        super(:bad_request, "Missing body", "A body was expected, none found")
      end
    end

    class BadContentType < Error
      def initialize
        super(:bad_request, "Bad content-type", "Request content-type is missing or unsupported")
      end
    end

    class BadParameter < Error
      class Parameter
        include JSON::Serializable
        property name : String
        property issue : String
        def initialize(@name, @issue)
        end
      end

      def initialize(@parameters : Array(Parameter))
        super(:bad_parameter, "Bad parameter", message)
      end
    end
  end
end