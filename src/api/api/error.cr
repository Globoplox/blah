class Exception
  @[JSON::Field(ignore: true)]
  @cause : Exception?
  @[JSON::Field(ignore: true)]
  @callstack : CallStack?
end

class Api
  class Error < Exception

    enum Code
      UNAUTHENTICATED
      UNAUTHORIZED
      INVALID_CREDENTIALS
      BAD_REQUEST
      BAD_PARAMETER
      SERVER_ERROR
      NOT_FOUND
      QUOTAS
    end

    def self.status_for(code : Code) : HTTP::Status
      case code
      in Code::UNAUTHENTICATED then HTTP::Status::UNAUTHORIZED
      in Code::UNAUTHORIZED then HTTP::Status::FORBIDDEN
      in Code::INVALID_CREDENTIALS then HTTP::Status::FORBIDDEN
      in Code::BAD_REQUEST then HTTP::Status::BAD_REQUEST
      in Code::BAD_PARAMETER then HTTP::Status::UNPROCESSABLE_ENTITY
      in Code::SERVER_ERROR then HTTP::Status::INTERNAL_SERVER_ERROR
      in Code::NOT_FOUND then HTTP::Status::NOT_FOUND
      in Code::QUOTAS then HTTP::Status::FORBIDDEN
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
      def initialize(message)
        super(:not_found, message)
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

    class Authentication < Error
      def initialize(message)
        super(:unauthenticated, "Unauthorized", message)
      end
    end

    class BadRequest < Error
      def initialize(message)
        super(:bad_request, "bad rquest", message)
      end
    end

    class Unauthorized < Error
      def initialize(message)
        super(:unauthorized, "Unauthorized", message)
      end
    end

    class Quotas < Error
      def initialize(message)
        super(:quotas, "Unauthorized", message)
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

    def self.bad_parameter(name, issue)
      BadParameter.new [BadParameter::Parameter.new name, issue]
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