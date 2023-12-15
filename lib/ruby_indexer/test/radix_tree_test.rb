# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyIndexer
  class RadixTreeTest < Minitest::Test
    def test_empty
      tree = PrefixTree.new

      assert_empty(tree.search(""))
      assert_empty(tree.search("foo"))
    end

    def test_single_item
      tree = RadixTree.new
      tree.insert("foo", "foo")

      assert_equal(["foo"], tree.search(""))
      assert_equal(["foo"], tree.search("foo"))
      assert_empty(tree.search("bar"))
    end

    def test_split_items
      tree = RadixTree.new
      tree.insert("foo", "foo")
      tree.insert("fo", "fo")

      assert_equal(["fo", "foo"], tree.search(""))
      assert_equal(["fo", "foo"], tree.search("fo"))
      assert_equal(["foo"], tree.search("foo"))
    end

    def test_complex_split_items
      tree = RadixTree.new
      tree.insert("foo", "foo")
      tree.insert("fob", "fob")

      assert_equal(["foo", "fob"], tree.search(""))
      assert_equal(["foo", "fob"], tree.search("fo"))
      assert_equal(["foo"], tree.search("foo"))
    end

    def test_multiple_items
      tree = RadixTree[String].new
      ["foo", "bar", "baz"].each { |item| tree.insert(item, item) }

      assert_equal(["foo", "bar", "baz"], tree.search(""))
      assert_equal(["bar", "baz"], tree.search("b"))
      assert_equal(["foo"], tree.search("fo"))
      assert_equal(["bar", "baz"], tree.search("ba"))
      assert_equal(["baz"], tree.search("baz"))
      assert_empty(tree.search("qux"))
    end

    def test_multiple_prefixes
      tree = RadixTree[String].new
      ["fo", "foo"].each { |item| tree.insert(item, item) }

      assert_equal(["fo", "foo"], tree.search(""))
      assert_equal(["fo", "foo"], tree.search("f"))
      assert_equal(["fo", "foo"], tree.search("fo"))
      assert_equal(["foo"], tree.search("foo"))
      assert_empty(tree.search("fooo"))
    end

    def test_multiple_prefixes_with_shuffled_order
      tree = RadixTree[String].new
      [
        "foo/bar/base",
        "foo/bar/on",
        "foo/bar/support/selection",
        "foo/bar/support/runner",
        "foo/internal",
        "foo/bar/document",
        "foo/bar/code",
        "foo/bar/support/rails",
        "foo/bar/diagnostics",
        "foo/bar/document2",
        "foo/bar/support/runner2",
        "foo/bar/support/diagnostic",
        "foo/document",
        "foo/bar/formatting",
        "foo/bar/support/highlight",
        "foo/bar/semantic",
        "foo/bar/support/prefix",
        "foo/bar/folding",
        "foo/bar/selection",
        "foo/bar/support/syntax",
        "foo/bar/document3",
        "foo/bar/hover",
        "foo/bar/support/semantic",
        "foo/bar/support/source",
        "foo/bar/inlay",
        "foo/requests",
        "foo/bar/support/formatting",
        "foo/bar/path",
        "foo/executor",
      ].each { |item| tree.insert(item, item) }

      assert_equal(
        [
          "foo/bar/support/selection",
          "foo/bar/support/semantic",
          "foo/bar/support/syntax",
          "foo/bar/support/source",
          "foo/bar/support/runner",
          "foo/bar/support/runner2",
          "foo/bar/support/rails",
          "foo/bar/support/diagnostic",
          "foo/bar/support/highlight",
          "foo/bar/support/prefix",
          "foo/bar/support/formatting",
        ].sort,
        tree.search("foo/bar/support").sort,
      )

      # Verify that the tree structure is correct
      assert_equal(<<~TREE, tree.print_tree)
        "" => nil
          "foo/" => nil
              "bar/" => nil
                  "base" => "foo/bar/base"
                  "on" => "foo/bar/on"
                  "code" => "foo/bar/code"
                  "d" => nil
                      "ocument" => "foo/bar/document"
                          "2" => "foo/bar/document2"
                          "3" => "foo/bar/document3"
                      "iagnostics" => "foo/bar/diagnostics"
                  "s" => nil
                      "upport/" => nil
                          "r" => nil
                              "unner" => "foo/bar/support/runner"
                                  "2" => "foo/bar/support/runner2"
                              "ails" => "foo/bar/support/rails"
                          "diagnostic" => "foo/bar/support/diagnostic"
                          "highlight" => "foo/bar/support/highlight"
                          "prefix" => "foo/bar/support/prefix"
                          "s" => nil
                              "yntax" => "foo/bar/support/syntax"
                              "e" => nil
                                  "lection" => "foo/bar/support/selection"
                                  "mantic" => "foo/bar/support/semantic"
                              "ource" => "foo/bar/support/source"
                          "formatting" => "foo/bar/support/formatting"
                      "e" => nil
                          "mantic" => "foo/bar/semantic"
                          "lection" => "foo/bar/selection"
                  "fo" => nil
                      "rmatting" => "foo/bar/formatting"
                      "lding" => "foo/bar/folding"
                  "hover" => "foo/bar/hover"
                  "inlay" => "foo/bar/inlay"
                  "path" => "foo/bar/path"
              "internal" => "foo/internal"
              "document" => "foo/document"
              "requests" => "foo/requests"
              "executor" => "foo/executor"
      TREE
    end

    def test_deletion
      tree = RadixTree[String].new
      ["foo/bar", "foo/baz"].each { |item| tree.insert(item, item) }
      assert_equal(["foo/bar", "foo/baz"], tree.search("foo"))

      tree.delete("foo/bar")
      assert_empty(tree.search("foo/bar"))
      assert_equal(["foo/baz"], tree.search("foo"))
    end

    def test_delete_does_not_impact_other_keys_with_the_same_value
      tree = RadixTree[String].new
      tree.insert("key1", "value")
      tree.insert("key2", "value")
      assert_equal(["value", "value"], tree.search("key"))

      tree.delete("key2")
      assert_empty(tree.search("key2"))
      assert_equal(["value"], tree.search("key1"))
    end

    def test_deleted_node_is_removed_from_the_tree
      tree = RadixTree[String].new
      tree.insert("foo/bar", "foo/bar")
      assert_equal(["foo/bar"], tree.search("foo"))

      tree.delete("foo/bar")
      root = tree.instance_variable_get(:@root)
      assert_empty(root.children)
    end

    def test_deleting_non_terminal_nodes
      tree = RadixTree[String].new
      tree.insert("abc", "value1")
      tree.insert("abcdef", "value2")

      tree.delete("abcdef")
      assert_empty(tree.search("abcdef"))
      assert_equal(["value1"], tree.search("abc"))
    end

    def test_overriding_values
      tree = RadixTree[Integer].new

      tree.insert("foo/bar", 123)
      assert_equal([123], tree.search("foo/bar"))

      tree.insert("foo/bar", 456)
      assert_equal([456], tree.search("foo/bar"))
    end
  end
end
