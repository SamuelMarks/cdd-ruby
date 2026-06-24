# frozen_string_literal: true

require_relative 'cdd'
require 'json'

module Cdd
  # Synchronizes CDD codebase modifications back into the OpenAPI specification
  class Sync
    # Synchronizes bidirectional changes
    # @param input [String] the OpenAPI json definition
    # @param truth [String] the single source of truth ('class', 'activerecord', 'function')
    # @return [void]
    def self.sync(input, truth)
      # Reverse-parse the entire generated directory tree
      dir = File.dirname(input)
      ir = Cdd::IR.new
      ir.openapi_spec = JSON.parse(File.read(input))

      # Iterate all ruby files in the same directory structure (e.g. server project)
      Dir.glob(File.join(dir, '**', '*.rb')).each do |file|
        next if file.include?('/spec/') || file.include?('/tests/') || file.include?('/vendor/') || file.include?('/.bundle/')

        tokens = Ripper.lex(File.read(file))

        if %w[class activerecord].include?(truth.downcase)
          Cdd::Classes::Parser.parse(tokens, ir)
        elsif truth.downcase == 'function'
          Cdd::Routes::Parser.parse(tokens, ir)
          Cdd::Functions::Parser.parse(tokens, ir)
        end
      end

      # For now, just rewrite the JSON spec with the parsed artifacts.
      File.write(input, JSON.pretty_generate(ir.openapi_spec))
    end
  end
end
