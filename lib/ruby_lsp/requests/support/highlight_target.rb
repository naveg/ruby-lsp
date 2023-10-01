# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Requests
    module Support
      class HighlightTarget
        extend T::Sig

        READ = Constant::DocumentHighlightKind::READ
        WRITE = Constant::DocumentHighlightKind::WRITE

        class HighlightMatch
          extend T::Sig

          sig { returns(Integer) }
          attr_reader :type

          sig { returns(Prism::Location) }
          attr_reader :location

          sig { params(type: Integer, location: Prism::Location).void }
          def initialize(type:, location:)
            @type = type
            @location = location
          end
        end

        sig { params(node: Prism::Node).void }
        def initialize(node)
          @node = node
          @value = T.let(value(node), T.nilable(String))
        end

        sig { params(other: Prism::Node).returns(T.nilable(HighlightMatch)) }
        def highlight_type(other)
          matched_highlight(other) if @value && @value == value(other)
        end

        private

        # Match the target type (where the cursor is positioned) with the `other` type (the node we're currently
        # visiting)
        sig { params(other: Prism::Node).returns(T.nilable(HighlightMatch)) }
        def matched_highlight(other)
          case @node
          # Method definitions and invocations
          when Prism::CallNode, Prism::DefNode
            case other
            when Prism::CallNode
              HighlightMatch.new(type: READ, location: other.location)
            when Prism::DefNode
              HighlightMatch.new(type: WRITE, location: other.name_loc)
            end
          # Variables, parameters and constants
          else
            case other
            when Prism::GlobalVariableTargetNode, Prism::InstanceVariableTargetNode, Prism::ConstantPathTargetNode,
              Prism::ConstantTargetNode, Prism::ClassVariableTargetNode, Prism::LocalVariableTargetNode,
              Prism::BlockParameterNode, Prism::RequiredParameterNode

              HighlightMatch.new(type: WRITE, location: other.location)
            when Prism::LocalVariableWriteNode, Prism::KeywordParameterNode, Prism::RestParameterNode,
              Prism::OptionalParameterNode, Prism::KeywordRestParameterNode, Prism::LocalVariableAndWriteNode,
              Prism::LocalVariableOperatorWriteNode, Prism::LocalVariableOrWriteNode, Prism::ClassVariableWriteNode,
              Prism::ClassVariableOrWriteNode, Prism::ClassVariableOperatorWriteNode, Prism::ClassVariableAndWriteNode,
              Prism::ConstantWriteNode, Prism::ConstantOrWriteNode, Prism::ConstantOperatorWriteNode,
              Prism::InstanceVariableWriteNode, Prism::ConstantAndWriteNode, Prism::InstanceVariableOrWriteNode,
              Prism::InstanceVariableAndWriteNode, Prism::InstanceVariableOperatorWriteNode,
              Prism::GlobalVariableWriteNode, Prism::GlobalVariableOrWriteNode, Prism::GlobalVariableAndWriteNode,
              Prism::GlobalVariableOperatorWriteNode

              HighlightMatch.new(type: WRITE, location: T.must(other.name_loc)) if other.name
            when Prism::ConstantPathWriteNode, Prism::ConstantPathOrWriteNode, Prism::ConstantPathAndWriteNode,
              Prism::ConstantPathOperatorWriteNode

              HighlightMatch.new(type: WRITE, location: other.target.location)
            when Prism::LocalVariableReadNode, Prism::ConstantPathNode, Prism::ConstantReadNode,
              Prism::InstanceVariableReadNode, Prism::ClassVariableReadNode, Prism::GlobalVariableReadNode

              HighlightMatch.new(type: READ, location: other.location)
            when Prism::ClassNode, Prism::ModuleNode
              HighlightMatch.new(type: WRITE, location: other.constant_path.location)
            end
          end
        end

        sig { params(node: Prism::Node).returns(T.nilable(String)) }
        def value(node)
          case node
          when Prism::ConstantReadNode, Prism::ConstantPathNode, Prism::BlockArgumentNode, Prism::ConstantTargetNode,
            Prism::ConstantPathWriteNode, Prism::ConstantPathTargetNode, Prism::ConstantPathOrWriteNode,
            Prism::ConstantPathOperatorWriteNode, Prism::ConstantPathAndWriteNode
            node.slice
          when Prism::GlobalVariableReadNode, Prism::GlobalVariableAndWriteNode, Prism::GlobalVariableOperatorWriteNode,
            Prism::GlobalVariableOrWriteNode, Prism::GlobalVariableTargetNode, Prism::GlobalVariableWriteNode,
            Prism::InstanceVariableAndWriteNode, Prism::InstanceVariableOperatorWriteNode,
            Prism::InstanceVariableOrWriteNode, Prism::InstanceVariableReadNode, Prism::InstanceVariableTargetNode,
            Prism::InstanceVariableWriteNode, Prism::ConstantAndWriteNode, Prism::ConstantOperatorWriteNode,
            Prism::ConstantOrWriteNode, Prism::ConstantWriteNode, Prism::ClassVariableAndWriteNode,
            Prism::ClassVariableOperatorWriteNode, Prism::ClassVariableOrWriteNode, Prism::ClassVariableReadNode,
            Prism::ClassVariableTargetNode, Prism::ClassVariableWriteNode, Prism::LocalVariableAndWriteNode,
            Prism::LocalVariableOperatorWriteNode, Prism::LocalVariableOrWriteNode, Prism::LocalVariableReadNode,
            Prism::LocalVariableTargetNode, Prism::LocalVariableWriteNode, Prism::DefNode, Prism::BlockParameterNode,
            Prism::KeywordParameterNode, Prism::KeywordRestParameterNode, Prism::OptionalParameterNode,
            Prism::RequiredParameterNode, Prism::RestParameterNode

            node.name.to_s
          when Prism::CallNode
            node.message
          when Prism::ClassNode, Prism::ModuleNode
            node.constant_path.slice
          end
        end
      end
    end
  end
end
