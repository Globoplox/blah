class Exception
  @[JSON::Field(ignore: true)]
  @cause : Exception?
  @[JSON::Field(ignore: true)]
  @callstack : CallStack?
end

class Api
  class Error < Exception
    include JSON::Serializable
    property code : HTTP::Status
    property error : String
    property message : String?

    def initialize(@code, @error, @message)
    end

    def self.validation(field, message)
      Error.new HTTP::Status::UNPROCESSABLE_ENTITY, field, message
    end

    class NotFound < Error
      def initialize(resource)
        @code = HTTP::Status::NOT_FOUND
        @error = "Not found"
        @message = "The resource #{resource} was not found"
      end
    end

    class Auth < Error
      def initialize(@message)
        @code = HTTP::Status::UNAUTHORIZED
        @error = "Unauthorized"
      end
    end

    class MissingBody < Error
      def initialize
        @code = HTTP::Status::UNPROCESSABLE_ENTITY
        @error = "Missing body"
        @message = "A body was expected, none found"
      end
    end

    class BadContentType < Error
      def initialize
        @code = HTTP::Status::UNPROCESSABLE_ENTITY
        @error = "Bad content-type"
        @message = "Request content-type is missing or unsupported"
      end
    end

    class Validations < Error
      include JSON::Serializable
      property causes : Array(Error)

      def initialize(@causes : Array(Error))
        @code = HTTP::Status::UNPROCESSABLE_ENTITY
        @error = "Validation"
        @message = "Invalid body"
      end
    end
  end
end
