# frozen_string_literal: true

require_relative 'cdd'
require 'json'
require 'pathname'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Synchronizes CDD codebase modifications back into the OpenAPI specification.
  class Sync
    # Directory names excluded from synchronization scanning.
    EXCLUDED_DIRS = %w[spec tests vendor .bundle].freeze

    # Synchronizes bidirectional changes from Ruby source files into the OpenAPI or Arazzo JSON file.
    #
    # @param input [String] the OpenAPI or Arazzo JSON definition filepath
    # @param truth [String] the single source of truth (`'class'`, `'activerecord'`, `'function'`, `'workflow'`)
    # @return [void]
    def self.sync(input, truth)
      dir = File.dirname(input)
      base_path = Pathname.new(dir)
      raw = JSON.parse(File.read(input))
      is_arazzo = raw.key?('arazzo') || truth.downcase == 'workflow'
      ir = is_arazzo ? Cdd::IR.new(nil, raw) : Cdd::IR.new(raw)

      Dir.glob(File.join(dir, '**', '*.rb')).each do |file|
        rel_segments = Pathname.new(file).relative_path_from(base_path).each_filename.to_a
        next if rel_segments.intersect?(EXCLUDED_DIRS)

        tokens = Ripper.lex(File.read(file))
        if is_arazzo
          Cdd::Arazzo::Parser.parse(tokens, ir)
        elsif %w[class activerecord].include?(truth.downcase)
          Cdd::Classes::Parser.parse(tokens, ir)
          Cdd::Mocks::Parser.parse(tokens, ir)
        else
          Cdd::Openapi::Parser.parse(tokens, ir)
          Cdd::Docstrings::Parser.parse(tokens, ir)
          Cdd::Routes::Parser.parse(tokens, ir)
          Cdd::Functions::Parser.parse(tokens, ir)
        end
      end

      File.write(input, JSON.pretty_generate(is_arazzo ? ir.arazzo_spec : ir.openapi_spec))
    end
  end
end
