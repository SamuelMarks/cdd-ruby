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
          if token[1] == :on_ident && %w[get post put delete patch options head trace].include?(token[2].downcase)
            # Find next non-space token
            j = i + 1
            while j < tokens.size && tokens[j][1] == :on_sp
              j += 1
            end
            
            # Expecting string content
            if tokens[j] && (tokens[j][1] == :on_tstring_beg || tokens[j][1] == :on_tstring_content)
              # if it's tstring_beg, find the actual content
              path_token = tokens[j..j+2].find { |t| t[1] == :on_tstring_content }
              if path_token
                method = token[2].downcase
                path = path_token[2]
                
                ir.openapi_spec["paths"] ||= {}
                ir.openapi_spec["paths"][path] ||= {}
                ir.openapi_spec["paths"][path][method] ||= {
                  "responses" => { "200" => { "description" => "OK" } }
                }
              end
            end
          end
        end
      end
    end
  end
end
