# typed: true
# frozen_string_literal: true

module RubyIndexer
  # A PrefixTree is a data structure that allows searching for partial strings fast. The tree is similar to a nested
  # hash structure, where the keys are the characters of the inserted strings.
  #
  # ## Example
  # ```ruby
  # tree = PrefixTree[String].new
  # # Insert entries using the same key and value
  # tree.insert("bar", "bar")
  # tree.insert("baz", "baz")
  # # Internally, the structure is analogous to this, but using nodes:
  # # {
  # #   "b" => {
  # #     "a" => {
  # #       "r" => "bar",
  # #       "z" => "baz"
  # #     }
  # #   }
  # # }
  # # When we search it, it finds all possible values based on partial (or complete matches):
  # tree.search("") # => ["bar", "baz"]
  # tree.search("b") # => ["bar", "baz"]
  # tree.search("ba") # => ["bar", "baz"]
  # tree.search("bar") # => ["bar"]
  # ```
  #
  # A PrefixTree is useful for autocomplete, since we always want to find all alternatives while the developer hasn't
  # finished typing yet. This PrefixTree implementation allows for string keys and any arbitrary value using the generic
  # `Value` type.
  #
  # See https://en.wikipedia.org/wiki/Trie for more information
  class RadixTree
    extend T::Sig
    extend T::Generic

    Value = type_member { { upper: Object } }

    sig { void }
    def initialize
      @root = T.let(Node.new(""), Node[Value])
    end

    # Search the PrefixTree based on a given `prefix`. If `foo` is an entry in the tree, then searching for `fo` will
    # return it as a result. The result is always an array of the type of value attribute to the generic `Value` type.
    # Notice that if the `Value` is an array, this method will return an array of arrays, where each entry is the array
    # of values for a given match
    sig { params(prefix: String).returns(T::Array[Value]) }
    def search(prefix)
      node = find_node(prefix)
      return [] unless node

      node.collect
    end

    # Inserts a `value` using the given `key`
    sig { params(key: String, value: Value).void }
    def insert(key, value)
      node = T.let(@root, Node[Value])
      characters_matched = 0

      while characters_matched < key.length
        remaining_key = T.must(key[-(key.length - characters_matched)..])
        found_key, found_node = node.children.find { |edge, _node| remaining_key.start_with?(edge) }
        break unless found_node

        node = found_node
        characters_matched += T.must(found_key).length
      end

      # We matched exactly all characters in the key, so all we need to do is insert a child
      if characters_matched == key.length
        node.value = value
        return
      end

      rest_of_key = T.must(key[-(key.length - characters_matched)..])

      # We need to find all the nodes that share a common prefix with the requested insertion and then split them
      node_to_split = T.let(nil, T.nilable(Node[Value]))
      max_len = 0
      node.children.each do |edge, child_node|
        i = 0
        i += 1 while i < edge.length && i < rest_of_key.length && edge[i] == rest_of_key[i]

        if i > max_len
          node_to_split = child_node
          max_len = i
        end
      end

      # If the node is a leaf, then it has no children and therefore there is never a need to split the key. We can just
      # insert its first child
      unless node_to_split
        node.children[rest_of_key] = Node.new(rest_of_key, value, node)
        return
      end

      prefix = T.must(rest_of_key[0...max_len])
      # Let's create a new intermediate node on which we'll nest the children of the longest matching prefix node
      new_node = node.children[prefix] = Node.new(prefix, nil, node)

      remaining_split_key = T.must(node_to_split.key[max_len...])
      # We delete the old longest matching node
      node.children.delete(node_to_split.key)
      node_to_split.key = remaining_split_key
      node_to_split.parent = new_node
      new_node.children[remaining_split_key] = node_to_split

      # Now we can insert the new node
      node.children[prefix] = new_node

      if key == prefix
        new_node.value = value
      else
        # Now we can insert the new node for the remaining of the key
        remaining_split_key = T.must(rest_of_key[max_len...])
        new_node.children[remaining_split_key] = Node.new(remaining_split_key, value, new_node)
      end
    end

    # Deletes the entry identified by `key` from the tree. Notice that a partial match will still delete all entries
    # that match it. For example, if the tree contains `foo` and we ask to delete `fo`, then `foo` will be deleted
    sig { params(key: String).void }
    def delete(key)
      node = find_node(key)
      return unless node

      # TODO: if we delete a value and it leaves only one child, we need to compress the tree back (reverse of
      # splitting)

      # Remove the node from the tree and then go up the parents to remove any of them with empty children
      parent = T.let(T.must(node.parent), T.nilable(Node[Value]))

      while parent
        parent.children.delete(node.key)
        return if !parent.leaf? || parent.value?

        node = parent
        parent = parent.parent
      end
    end

    sig { returns(String) }
    def print_tree
      @root.print_node
    end

    private

    # Find a node (leaf or not) that matches the given `key`
    sig { params(key: String).returns(T.nilable(Node[Value])) }
    def find_node(key)
      node = T.let(@root, T.nilable(Node[Value]))
      characters_matched = 0

      while node && !node.leaf? && characters_matched < key.length
        remaining_key = T.must(key[-(key.length - characters_matched)..])

        node.children.each do |edge, next_node|
          if remaining_key.start_with?(edge)
            node = next_node
            characters_matched += edge.length
            break
          elsif edge.start_with?(remaining_key)
            node = next_node
            characters_matched += remaining_key.length
            break
          else
            node = nil
          end
        end
      end

      # Return unless the node contains a value and we matched all characters in the key
      return if characters_matched < key.length

      node
    end

    class Node
      extend T::Sig
      extend T::Generic

      Value = type_member { { upper: Object } }

      sig { returns(T::Hash[String, Node[Value]]) }
      attr_reader :children

      sig { returns(String) }
      attr_accessor :key

      sig { returns(T.nilable(Value)) }
      attr_accessor :value

      sig { returns(T.nilable(Node[Value])) }
      attr_accessor :parent

      sig { params(key: String, value: T.nilable(Value), parent: T.nilable(Node[Value])).void }
      def initialize(key, value = nil, parent = nil)
        @key = key
        @value = value
        @parent = parent
        @children = {}
      end

      sig { returns(T::Boolean) }
      def value?
        !!@value
      end

      sig { returns(T::Boolean) }
      def leaf?
        @children.empty?
      end

      sig { returns(T::Array[Value]) }
      def collect
        result = []
        result << @value if value?

        @children.each_value do |node|
          result.concat(node.collect)
        end

        result
      end

      sig { params(level: Integer).returns(String) }
      def print_node(level = 0)
        indent = "  " * level
        <<~INSPECT.chomp
          #{indent}#{@key.inspect} => #{@value.inspect}
          #{children.map { |_k, v| "#{indent}#{v.print_node(level + 1)}" }.join}
        INSPECT
      end
    end
  end
end
