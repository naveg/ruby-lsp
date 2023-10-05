# typed: strict
# frozen_string_literal: true

require_relative "lib/ruby_lsp/internal"

before = %x(ps -o rss= -p #{$$}).to_i

i = RubyIndexer::Index.new
i.index_all

after = %x(ps -o rss= -p #{$$}).to_i
difference = after - before
puts "Memory usage: #{difference.to_f / 1024} MB"
