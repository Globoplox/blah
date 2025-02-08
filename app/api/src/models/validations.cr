require "../api/error"

module Validations
  extend self
  
  BANNED_PASSWORDS = {{read_file("#{__DIR__}/banned_passwords.txt").lines}}

  def validate(acc)
    acc = Accumulator.new
    with acc yield
    return acc
  end

  def validate!(acc = nil)
    acc ||= Accumulator.new
    with acc yield
    raise Api::Error::BadParameter.new parameters: acc.bad_parameters unless acc.bad_parameters.empty?
  end
  
  struct Accumulator
    property bad_parameters : Array(Api::Error::BadParameter::Parameter) 

    def initialize()
      @bad_parameters = [] of Api::Error::BadParameter::Parameter
    end

    def initialize(@bad_parameters)
    end

    def accumulate(name, error)
      @bad_parameters << Api::Error::BadParameter::Parameter.new name, error if error
    end

    def check_username(name : String) : String?
      return "must be at least 3 character" if name.size < 3
      return "must be at most 50 character" if name.size > 50
      return "must only contains printable character" if name.chars.any? { |c| !c.printable? }
      return "cannot contains whitespace" if name.chars.any? { |c| c.whitespace? }
    end

    def check_email(email : String) : String?
      nil
    end

    def check_password(password : String, email, name) : String?
      return "must be at least 8 character" if password.size < 8
      return "must be at most 100 character" if password.size > 100
      return "cannot be the same as email" if email && password == email
      return "cannot be the same as name" if name && password == name
      return "must not be one of the most commons weak passwords" if password.in? BANNED_PASSWORDS
    end
   
    def check_project_description(description) : String?
      return "must be at least 3 character" if description.size < 3
      return "must be at most 50 character" if description.size > 1000
    end

    def check_project_name(name) : String?
      return "must be at least 3 character" if name.size < 3
      return "must be at most 50 character" if name.size > 50
      return "must only contains printable character" if name.chars.any? { |c| !c.printable? }
      return "cannot contains whitespace" if name.chars.any? { |c| c.whitespace? }
    end

    def check_file_path(path) : String?
      return "must be at most 50 character" if path.size > 1000
      return "must starts with a /" unless path.starts_with? '/'
      return "must not end with a /" if path.ends_with? '/'
      path.scan("//") do
        return "must not have several repeated /"
      end
      alloweds = "azertyuiopqsdfghjklmwxcvbnAZERTYUIOPQSDFGHJKLMWXCVBN-_./".chars
      path.chars.each do |char|
        return "must only contain alphanumeric or '/-_.' characters, " unless char.in? alloweds
      end
    end

    def check_directory_path(path) : String?
      return "cannot be the root ('/') direcotry" if path == "/"
      return "must be at most 50 character" if path.size > 1000
      return "must starts with a /" unless path.starts_with? '/'
      return "must end with a /" unless path.ends_with? '/'
      path.scan("//") do
        return "must not have several repeated /"
      end
      alloweds = "azertyuiopqsdfghjklmwxcvbnAZERTYUIOPQSDFGHJKLMWXCVBN-_./".chars
      path.chars.each do |char|
        return "must only contain alphanumeric or '/-_.' characters, " unless char.in? alloweds
      end
    end

  end
end