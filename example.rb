# typed: strict
# frozen_string_literal: true

require "bundler/setup"
require "ruby_lsp/internal"

content = File.read("lib/ruby_lsp/requests/folding_ranges.rb")
ast = Prism.parse(content).value

class Dispatcher < Prism::Visitor
  def initialize
    # on_class_node => [listener1, listener2]
    @listeners = {}
    super()
  end

  def visit_class_node(node)
    @listeners[:on_class_node].each { |listener| listener.on_call_node(node) }
  end
end

dispatcher = Prism::Dispatcher.new

class HoverResponse
  def initialize
    @items = []
  end

  def <<(item)
    @items << item
  end
end

class FirstListener
  attr_reader :_response

  def initialize(dispatcher)
    dispatcher.register(self, :on_class_node_enter)
    @_response = []
  end

  def on_class_node_enter(node)
    @_response << "whatever"
  end
end

class SecondListener
  def initialize(response, dispatcher)
    dispatcher.register(self, :on_module_node_enter)
  end

  def on_module_node_enter(node)
    response << { category: :signature, content: "foo(a, b, c)" }
  end
end

first = FirstListener.new(dispatcher)
second = SecondListener.new(dispatcher)

listeners.each { |listener| final_response.concat(listener.response) }

dispatcher.visit(ast)

# class Visitor
#   def visit(node)
#     node&.accept(self)
#   end

#   def visit_class_node(node)
#     child_nodes.each { |child| visit(child) }
#   end
# end

# class ClassNode
#   def accept(visitor)
#     visitor.visit_class_node(self)
#   end
# end

# visitor = MyVisitor.new
# visitor.visit(ast)
