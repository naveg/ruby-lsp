# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Requests
    module Support
      module FormatterRunner
        extend T::Sig
        extend T::Helpers

        interface!

        sig do
          abstract.params(
            uri: URI::Generic,
            workspace_uri: URI::Generic,
            document: Document,
          ).returns(T.nilable(String))
        end
        def run(uri, workspace_uri, document); end
      end
    end
  end
end
