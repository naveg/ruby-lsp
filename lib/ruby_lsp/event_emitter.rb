# typed: strict
# frozen_string_literal: true

module RubyLsp
  # EventEmitter is an intermediary between our requests and Prism visitors. It's used to visit the document's AST
  # and emit events that the requests can listen to for providing functionality. Usages:
  #
  # - For positional requests, locate the target node and use `emit_for_target` to fire events for each listener
  # - For nonpositional requests, use `visit` to go through the AST, which will fire events for each listener as nodes
  # are found
  #
  # # Example
  #
  # ```ruby
  # target_node = document.locate_node(position)
  # emitter = EventEmitter.new
  # listener = Requests::Hover.new(emitter, @message_queue)
  # emitter.emit_for_target(target_node)
  # listener.response
  # ```
  class EventEmitter < Prism::Visitor
    extend T::Sig

    sig { void }
    def initialize
      @listeners = T.let(Hash.new { |h, k| h[k] = [] }, T::Hash[Symbol, T::Array[Listener[T.untyped]]])
      super()
    end

    sig { params(listener: Listener[T.untyped], events: Symbol).void }
    def register(listener, *events)
      events.each { |event| T.must(@listeners[event]) << listener }
    end

    # Emit events for a specific node. This is similar to the regular `visit` method, but avoids going deeper into the
    # tree for performance
    sig { params(node: T.nilable(Prism::Node)).void }
    def emit_for_target(node)
      case node
      when Prism::CallNode
        @listeners[:on_call]&.each { |l| T.unsafe(l).on_call(node) }
      when Prism::ConstantPathNode
        @listeners[:on_constant_path]&.each { |l| T.unsafe(l).on_constant_path(node) }
      when Prism::StringNode
        @listeners[:on_string]&.each { |l| T.unsafe(l).on_string(node) }
      when Prism::ClassNode
        @listeners[:on_class]&.each { |l| T.unsafe(l).on_class(node) }
      when Prism::ModuleNode
        @listeners[:on_module]&.each { |l| T.unsafe(l).on_module(node) }
      when Prism::ConstantWriteNode
        @listeners[:on_constant_write]&.each { |l| T.unsafe(l).on_constant_write(node) }
      when Prism::ConstantReadNode
        @listeners[:on_constant_read]&.each { |l| T.unsafe(l).on_constant_read(node) }
      end
    end

    # Visit dispatchers are below. Notice that for nodes that create a new scope (e.g.: classes, modules, method defs)
    # we need both an `on_*` and `after_*` event. This is because some requests must know when we exit the scope
    sig { override.params(node: T.nilable(Prism::Node)).void }
    def visit(node)
      @listeners[:on_node]&.each { |l| T.unsafe(l).on_node(node) }
      super
    end

    sig { params(nodes: T::Array[T.nilable(Prism::Node)]).void }
    def visit_all(nodes)
      nodes.each { |node| visit(node) }
    end

    sig { override.params(node: Prism::ClassNode).void }
    def visit_class_node(node)
      @listeners[:on_class]&.each { |l| T.unsafe(l).on_class(node) }
      super
      @listeners[:after_class]&.each { |l| T.unsafe(l).after_class(node) }
    end

    sig { override.params(node: Prism::ModuleNode).void }
    def visit_module_node(node)
      @listeners[:on_module]&.each { |l| T.unsafe(l).on_module(node) }
      super
      @listeners[:after_module]&.each { |l| T.unsafe(l).after_module(node) }
    end

    sig { override.params(node: Prism::CallNode).void }
    def visit_call_node(node)
      @listeners[:on_call]&.each { |l| T.unsafe(l).on_call(node) }
      super
      @listeners[:after_call]&.each { |l| T.unsafe(l).after_call(node) }
    end

    sig { override.params(node: Prism::InstanceVariableWriteNode).void }
    def visit_instance_variable_write_node(node)
      @listeners[:on_instance_variable_write]&.each { |l| T.unsafe(l).on_instance_variable_write(node) }
      super
    end

    sig { override.params(node: Prism::ClassVariableWriteNode).void }
    def visit_class_variable_write_node(node)
      @listeners[:on_class_variable_write]&.each { |l| T.unsafe(l).on_class_variable_write(node) }
      super
    end

    sig { override.params(node: Prism::DefNode).void }
    def visit_def_node(node)
      @listeners[:on_def]&.each { |l| T.unsafe(l).on_def(node) }
      super
      @listeners[:after_def]&.each { |l| T.unsafe(l).after_def(node) }
    end

    sig { override.params(node: Prism::BlockNode).void }
    def visit_block_node(node)
      @listeners[:on_block]&.each { |l| T.unsafe(l).on_block(node) }
      super
      @listeners[:after_block]&.each { |l| T.unsafe(l).after_block(node) }
    end

    sig { override.params(node: Prism::SelfNode).void }
    def visit_self_node(node)
      @listeners[:on_self]&.each { |l| T.unsafe(l).on_self(node) }
      super
    end

    sig { override.params(node: Prism::RescueNode).void }
    def visit_rescue_node(node)
      @listeners[:on_rescue]&.each { |l| T.unsafe(l).on_rescue(node) }
      super
    end

    sig { override.params(node: Prism::BlockParameterNode).void }
    def visit_block_parameter_node(node)
      @listeners[:on_block_parameter]&.each { |l| T.unsafe(l).on_block_parameter(node) }
      super
    end

    sig { override.params(node: Prism::KeywordParameterNode).void }
    def visit_keyword_parameter_node(node)
      @listeners[:on_keyword_parameter]&.each { |l| T.unsafe(l).on_keyword_parameter(node) }
      super
    end

    sig { override.params(node: Prism::KeywordRestParameterNode).void }
    def visit_keyword_rest_parameter_node(node)
      @listeners[:on_keyword_rest_parameter]&.each { |l| T.unsafe(l).on_keyword_rest_parameter(node) }
      super
    end

    sig { override.params(node: Prism::OptionalParameterNode).void }
    def visit_optional_parameter_node(node)
      @listeners[:on_optional_parameter]&.each { |l| T.unsafe(l).on_optional_parameter(node) }
      super
    end

    sig { override.params(node: Prism::RequiredParameterNode).void }
    def visit_required_parameter_node(node)
      @listeners[:on_required_parameter]&.each { |l| T.unsafe(l).on_required_parameter(node) }
      super
    end

    sig { override.params(node: Prism::RestParameterNode).void }
    def visit_rest_parameter_node(node)
      @listeners[:on_rest_parameter]&.each { |l| T.unsafe(l).on_rest_parameter(node) }
      super
    end

    sig { override.params(node: Prism::ConstantReadNode).void }
    def visit_constant_read_node(node)
      @listeners[:on_constant_read]&.each { |l| T.unsafe(l).on_constant_read(node) }
      super
    end

    sig { override.params(node: Prism::ConstantPathNode).void }
    def visit_constant_path_node(node)
      @listeners[:on_constant_path]&.each { |l| T.unsafe(l).on_constant_path(node) }
      super
    end

    sig { override.params(node: Prism::ConstantPathWriteNode).void }
    def visit_constant_path_write_node(node)
      @listeners[:on_constant_path_write]&.each { |l| T.unsafe(l).on_constant_path_write(node) }
      super
    end

    sig { override.params(node: Prism::ConstantWriteNode).void }
    def visit_constant_write_node(node)
      @listeners[:on_constant_write]&.each { |l| T.unsafe(l).on_constant_write(node) }
      super
    end

    sig { override.params(node: Prism::ConstantAndWriteNode).void }
    def visit_constant_and_write_node(node)
      @listeners[:on_constant_and_write]&.each { |l| T.unsafe(l).on_constant_and_write(node) }
      super
    end

    sig { override.params(node: Prism::ConstantOperatorWriteNode).void }
    def visit_constant_operator_write_node(node)
      @listeners[:on_constant_operator_write]&.each { |l| T.unsafe(l).on_constant_operator_write(node) }
      super
    end

    sig { override.params(node: Prism::ConstantOrWriteNode).void }
    def visit_constant_or_write_node(node)
      @listeners[:on_constant_or_write]&.each { |l| T.unsafe(l).on_constant_or_write(node) }
      super
    end

    sig { override.params(node: Prism::ConstantTargetNode).void }
    def visit_constant_target_node(node)
      @listeners[:on_constant_target]&.each { |l| T.unsafe(l).on_constant_target(node) }
      super
    end

    sig { override.params(node: Prism::LocalVariableWriteNode).void }
    def visit_local_variable_write_node(node)
      @listeners[:on_local_variable_write]&.each { |l| T.unsafe(l).on_local_variable_write(node) }
      super
    end

    sig { override.params(node: Prism::LocalVariableReadNode).void }
    def visit_local_variable_read_node(node)
      @listeners[:on_local_variable_read]&.each { |l| T.unsafe(l).on_local_variable_read(node) }
      super
    end

    sig { override.params(node: Prism::LocalVariableAndWriteNode).void }
    def visit_local_variable_and_write_node(node)
      @listeners[:on_local_variable_and_write]&.each { |l| T.unsafe(l).on_local_variable_and_write(node) }
      super
    end

    sig { override.params(node: Prism::LocalVariableOperatorWriteNode).void }
    def visit_local_variable_operator_write_node(node)
      @listeners[:on_local_variable_operator_write]&.each { |l| T.unsafe(l).on_local_variable_operator_write(node) }
      super
    end

    sig { override.params(node: Prism::LocalVariableOrWriteNode).void }
    def visit_local_variable_or_write_node(node)
      @listeners[:on_local_variable_or_write]&.each { |l| T.unsafe(l).on_local_variable_or_write(node) }
      super
    end

    sig { override.params(node: Prism::LocalVariableTargetNode).void }
    def visit_local_variable_target_node(node)
      @listeners[:on_local_variable_target]&.each { |l| T.unsafe(l).on_local_variable_target(node) }
      super
    end

    sig { override.params(node: Prism::BlockLocalVariableNode).void }
    def visit_block_local_variable_node(node)
      @listeners[:on_block_local_variable]&.each { |l| T.unsafe(l).on_block_local_variable(node) }
      super
    end

    sig { override.params(node: Prism::IfNode).void }
    def visit_if_node(node)
      @listeners[:on_if]&.each { |l| T.unsafe(l).on_if(node) }
      super
    end

    sig { override.params(node: Prism::InNode).void }
    def visit_in_node(node)
      @listeners[:on_in]&.each { |l| T.unsafe(l).on_in(node) }
      super
    end

    sig { override.params(node: Prism::WhenNode).void }
    def visit_when_node(node)
      @listeners[:on_when]&.each { |l| T.unsafe(l).on_when(node) }
      super
    end

    sig { override.params(node: Prism::InterpolatedStringNode).void }
    def visit_interpolated_string_node(node)
      @listeners[:on_interpolated_string]&.each { |l| T.unsafe(l).on_interpolated_string(node) }
      super
    end

    sig { override.params(node: Prism::ArrayNode).void }
    def visit_array_node(node)
      @listeners[:on_array]&.each { |l| T.unsafe(l).on_array(node) }
      super
    end

    sig { override.params(node: Prism::CaseNode).void }
    def visit_case_node(node)
      @listeners[:on_case]&.each { |l| T.unsafe(l).on_case(node) }
      super
    end

    sig { override.params(node: Prism::ForNode).void }
    def visit_for_node(node)
      @listeners[:on_for]&.each { |l| T.unsafe(l).on_for(node) }
      super
    end

    sig { override.params(node: Prism::HashNode).void }
    def visit_hash_node(node)
      @listeners[:on_hash]&.each { |l| T.unsafe(l).on_hash(node) }
      super
    end

    sig { override.params(node: Prism::SingletonClassNode).void }
    def visit_singleton_class_node(node)
      @listeners[:on_singleton_class]&.each { |l| T.unsafe(l).on_singleton_class(node) }
      super
    end

    sig { override.params(node: Prism::UnlessNode).void }
    def visit_unless_node(node)
      @listeners[:on_unless]&.each { |l| T.unsafe(l).on_unless(node) }
      super
    end

    sig { override.params(node: Prism::UntilNode).void }
    def visit_until_node(node)
      @listeners[:on_until]&.each { |l| T.unsafe(l).on_until(node) }
      super
    end

    sig { override.params(node: Prism::WhileNode).void }
    def visit_while_node(node)
      @listeners[:on_while]&.each { |l| T.unsafe(l).on_while(node) }
      super
    end

    sig { override.params(node: Prism::ElseNode).void }
    def visit_else_node(node)
      @listeners[:on_else]&.each { |l| T.unsafe(l).on_else(node) }
      super
    end

    sig { override.params(node: Prism::EnsureNode).void }
    def visit_ensure_node(node)
      @listeners[:on_ensure]&.each { |l| T.unsafe(l).on_ensure(node) }
      super
    end

    sig { override.params(node: Prism::BeginNode).void }
    def visit_begin_node(node)
      @listeners[:on_begin]&.each { |l| T.unsafe(l).on_begin(node) }
      super
    end

    sig { override.params(node: Prism::StringConcatNode).void }
    def visit_string_concat_node(node)
      @listeners[:on_string_concat]&.each { |l| T.unsafe(l).on_string_concat(node) }
      super
    end
  end
end
