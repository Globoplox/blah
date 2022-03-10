require "./object"

# Dead code elimination
module RiSC16::Dce

  private class Node
    property section : Object::Section
    property users : Array(Node) = [] of Node    
    def initialize(@section : Object::Section) end
  end

  private def self.weak(node, stack = [] of Node)
    return false unless node.section.options.weak?
    return true if node.in? stack
    stack += [node]
    node.users.all? do |user|
      weak user, stack
    end
  end
  
  # Remove weak sections fragments from objects if they does not export a symbol actualy referenced (directly or indirectly)
  # By a a non weak sections fragments.
  def self.optimize(objects)
    cache = objects.flat_map &.sections.map { |section| Node.new section}

    cache.each do |node|
      cache.each do |other|
        next if other == node
        exported = node.section.definitions.select { |_,symbol| symbol.exported }.keys
        node.users << other if other.section.references.keys.any? &.in? exported
      end
    end
    
    to_trim = cache.select do |node|
      weak node
    end.map(&.section)

    objects.each &.sections.reject! &.in? to_trim
  end
  
end
