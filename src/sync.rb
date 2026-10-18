# frozen_string_literal: true

require_relative 'cdd'
require 'json'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Synchronizes CDD codebase modifications back into the OpenAPI specification.
  class Sync
    # Synchronizes bidirectional changes from Ruby source files into the OpenAPI or Arazzo JSON file.
    #
    # @param input [String] the OpenAPI or Arazzo JSON definition filepath
    # @param truth [String] the single source of truth (`'class'`, `'activerecord'`, `'function'`, `'workflow'`)
    # @return [void]
    def self.sync(input, truth)
      dir = File.dirname(input)
      raw = JSON.parse(File.read(input))
      is_arazzo = raw.key?('arazzo') || truth.downcase == 'workflow'
      ir = is_arazzo ? Cdd::IR.new(nil, raw) : Cdd::IR.new(raw)

      Dir.glob(File.join(dir, '**', '*.rb')).each do |file|
        next if file.include?('/spec/') || file.include?('/tests/') ||
                file.include?('/vendor/') || file.include?('/.bundle/')

        tokens = Ripper.lex(File.read(file))
        if is_arazzo
          Cdd::Arazzo::Parser.parse(tokens, ir)
        elsif %w[class activerecord].include?(truth.downcase)
          Cdd::Classes::Parser.parse(tokens, ir)
        else
          Cdd::Routes::Parser.parse(tokens, ir)
          Cdd::Functions::Parser.parse(tokens, ir)
        end
      end

      File.write(input, JSON.pretty_generate(is_arazzo ? ir.arazzo_spec : ir.openapi_spec))
    end
  end
end
