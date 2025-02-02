# Application business logic
class App
  def initialize(@storage : Storage, @schema : Schema, @cache : Cache)
  end
end

require "./*"