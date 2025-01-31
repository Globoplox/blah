require "./object"

# Represent a static lib, AKA a collection of objects.
class RiSC16::Lib
  property name : String
  property objects : Array(RiSC16::Object)

  def initialize(@objects, @name)
  end

  def to_io(io, endian = Object::ENDIAN)
    objects.size.to_io io, endian
    objects.each do |object|
      object.name.size.to_io io, endian
      io << object.name
      object.to_io io, endian
    end
  end

  def self.from_io(io : IO, name : String, endian = Object::ENDIAN)
    self.new name: name, objects: Array(Object).new(Int32.from_io(io, endian)) {
      name_size = Int32.from_io io, endian
      name = io.read_string name_size
      Object.from_io io, name, endian
    }
  end
end
