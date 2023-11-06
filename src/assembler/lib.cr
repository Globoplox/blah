require "./object"

# Represent a static lib, AKA a collection of objects.
class RiSC16::Lib
  property objects : Array(RiSC16::Object)

  def initialize(@objects)
  end

  def to_io(io, endian = Object::ENDIAN)
    objects.size.to_io io, endian
    objects.each do |object|
      object.to_io io, endian
    end
  end

  def self.from_io(io, name = nil, endian = Object::ENDIAN)
    self.new Array(Object).new(Int32.from_io(io, endian)) {
      Object.from_io io, name, endian
    }
  end
end
