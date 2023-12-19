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
      node = @root
      key_length = key.length
      characters_matched = 0
      key_rest = key

      # Match characters as far as we can for the given `key`
      while characters_matched < key_length
        found_node = node.children.find { |node| key_rest.start_with?(node.key) }
        break unless found_node

        node = found_node
        characters_matched += found_node.key.length
        key_rest = T.must(key[-(key_length - characters_matched)..])
      end

      # If we matched all characters, then a node already exists for this key. We're just overriding its value
      if characters_matched == key_length
        node.value = value
        return
      end

      # If we didn't match all characters, then we need to check if there's a common prefix between the `key` and any of
      # the children of the current node, so that we can decide if we can just add another child or split an existing
      # node
      node_to_split = T.let(nil, T.nilable(Node[Value]))
      max_len = 0
      remaining_key_length = key_rest.length
      node.children.each do |child_node|
        edge = child_node.key
        edge_len = edge.length
        prefix_len = 0

        while prefix_len < edge_len && prefix_len < remaining_key_length && edge[prefix_len] == key_rest[prefix_len]
          prefix_len += 1
        end

        next if prefix_len < max_len

        node_to_split = child_node
        max_len = prefix_len
      end

      # If none of the child nodes share a common prefix with `key`, then this is a brand new child for the current node
      unless node_to_split
        node.children << Node.new(key_rest, value, node)
        return
      end

      # Let's create a new intermediate node on which we'll nest the children of the longest matching prefix node
      prefix = T.must(key_rest[0...max_len])
      remaining_split_key = T.must(node_to_split.key[max_len...])
      new_node = Node.new(prefix, nil, node)
      node.children << new_node

      # We remove the node that we're splitting
      node.children.delete(node_to_split)

      # Reassign the key and parent. The node that we're splitting will become a child of the new intermediate node and
      # its key will become only the part remaining after the common prefix
      node_to_split.key = remaining_split_key
      node_to_split.parent = new_node
      new_node.children << node_to_split

      # If the length of the common prefix covers the entire remaining key, then we should set the value of the new node
      # to be the new value instead of pushing a new child
      if max_len == remaining_key_length
        new_node.value = value
      else
        # If there are still characters remaining from `key`, then we create a new child
        new_node.children << Node.new(T.must(key_rest[max_len...]), value, new_node)
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
        parent.children.delete(node)
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

        node.children.each do |next_node|
          edge = next_node.key

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

      sig { returns(T::Array[Node[Value]]) }
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
        @children = []
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
        @children.each { |node| result.concat(node.collect) }
        result
      end

      sig { params(level: Integer).returns(String) }
      def print_node(level = 0)
        indent = "  " * level
        <<~INSPECT.chomp
          #{indent}#{@key.inspect} => #{@value.inspect}
          #{@children.map { |node| "#{indent}#{node.print_node(level + 1)}" }.join}
        INSPECT
      end
    end
  end
end
