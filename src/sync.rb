# frozen_string_literal: true

require_relative 'cdd'
require 'json'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Synchronizes CDD codebase modifications back into the OpenAPI specification.
  class Sync
    # Synchronizes bidirectional changes from Ruby source files into the OpenAPI JSON file.
    #
    # @param input [String] the OpenAPI JSON definition filepath
    # @param truth [String] the single source of truth (`'class'`, `'activerecord'`, `'function'`)
    # @return [void]
    def self.sync(input, truth)
      dir = File.dirname(input)
      ir = Cdd::IR.new(JSON.parse(File.read(input)))

      Dir.glob(File.join(dir, '**', '*.rb')).each do |file|
        next if file.include?('/spec/') || file.include?('/tests/') ||
                file.include?('/vendor/') || file.include?('/.bundle/')

        tokens = Ripper.lex(File.read(file))
        if %w[class activerecord].include?(truth.downcase)
          Cdd::Classes::Parser.parse(tokens, ir)
        else
          Cdd::Routes::Parser.parse(tokens, ir)
          Cdd::Functions::Parser.parse(tokens, ir)
        end
      end

      File.write(input, JSON.pretty_generate(ir.openapi_spec))
    end
  end
end
