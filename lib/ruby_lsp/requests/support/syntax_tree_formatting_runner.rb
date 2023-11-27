# typed: strict
# frozen_string_literal: true

begin
  require "syntax_tree"
  require "syntax_tree/cli"
rescue LoadError
  return
end

require "singleton"

module RubyLsp
  module Requests
    module Support
      # :nodoc:
      class SyntaxTreeFormattingRunner
        extend T::Sig
        include Singleton
        include Support::FormatterRunner

        sig { void }
        def initialize
          @options =
            T.let(
              begin
                opts = SyntaxTree::CLI::Options.new
                opts.parse(SyntaxTree::CLI::ConfigFile.new.arguments)
                opts
              end,
              SyntaxTree::CLI::Options,
            )
        end

        sig do
          override.params(
            uri: URI::Generic,
            workspace_uri: URI::Generic,
            document: Document,
          ).returns(T.nilable(String))
        end
        def run(uri, workspace_uri, document)
          relative_path = Pathname.new(T.must(uri.to_standardized_path || uri.opaque))
            .relative_path_from(T.must(workspace_uri.to_standardized_path))
          return if @options.ignore_files.any? { |pattern| File.fnmatch(pattern, relative_path) }

          SyntaxTree.format(
            document.source,
            @options.print_width,
            options: @options.formatter_options,
          )
        end
      end
    end
  end
end
