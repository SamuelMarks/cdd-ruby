# frozen_string_literal: true

# Documentation for Cdd
module Cdd
  # Module for routes handling
  module Routes
    # Parser for routes
    class Parser
      # Parses routes from tokens and adds to ir
      # @param tokens [Array] tokens array
      # @param ir [Cdd::IR] Intermediate Representation
      def self.parse(tokens, ir)
        tokens.each_with_index do |token, i|
          next unless token[1] == :on_ident && %w[get post put delete patch options head
                                                  trace].include?(token[2].downcase)

          # Find next non-space token
          j = i + 1
          j += 1 while j < tokens.size && tokens[j][1] == :on_sp

          # Expecting string content
          next unless tokens[j] && %i[on_tstring_beg on_tstring_content].include?(tokens[j][1])

          # if it's tstring_beg, find the actual content
          path_token = tokens[j..j + 2].find { |t| t[1] == :on_tstring_content }
          next unless path_token

          method = token[2].downcase
          path = path_token[2]

          ir.openapi_spec['paths'] ||= {}
          ir.openapi_spec['paths'][path] ||= {}
          ir.openapi_spec['paths'][path][method] ||= {
            'responses' => { '200' => { 'description' => 'OK' } }
          }
        end
      end
    end
  end
end
