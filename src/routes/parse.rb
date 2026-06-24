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

          # Ensure this ident is at the start of a statement (after a newline or semicolon)
          prev_meaningful = tokens[0...i].reverse.find { |t| t[1] != :on_sp && t[1] != :on_comment }
          next if prev_meaningful && prev_meaningful[1] == :on_symbeg # e.g., `:get`
          next if prev_meaningful && prev_meaningful[1] == :on_period # e.g., `args.delete`
          next if prev_meaningful && prev_meaningful[1] == :on_op && prev_meaningful[2] == '.' # e.g., `Net::HTTP.get`
          next if prev_meaningful && prev_meaningful[1] == :on_kw && prev_meaningful[2] == 'def' # e.g., `def get`
          next if prev_meaningful && prev_meaningful[1] == :on_ident # e.g., `something get`

          # Find next non-space token to ensure it isn't an array/hash lookup `options[:ephemeral]`
          j = i + 1
          j += 1 while j < tokens.size && tokens[j][1] == :on_sp

          next if tokens[j].nil?
          next if tokens[j][1] == :on_lbracket # options[...]
          next if tokens[j][1] == :on_op && tokens[j][2] == '=' # options = ...
          next if tokens[j][1] == :on_nl # standalone `options\n`
          next if tokens[j][1] == :on_period # options.fetch(...)

          # We only consider it a Sinatra route if the immediate next token is a string (e.g. `get '/path'`)
          # or a paren opening `get('/path')`.
          # We skip it if it's an assignment, bracket lookup, method call dot, or standalone word.
          # To be very specific, we just ensure it starts a string.
          if tokens[j][1] == :on_lparen
            j += 1
            j += 1 while j < tokens.size && tokens[j][1] == :on_sp
          end

          # Expecting string content for the route path
          next unless tokens[j] && %i[on_tstring_beg on_tstring_content].include?(tokens[j][1])

          # if it's tstring_beg, find the actual content
          path_token = tokens[j..(j + 2)].find { |t| t[1] == :on_tstring_content }
          next unless path_token

          method = token[2].downcase
          path = path_token[2]

          # Only match valid HTTP route structures
          next unless path.start_with?('/')

          # Exclude internal MCP routes
          next if path.start_with?('/mcp/')

          # Extract parameter mappings from the path string (e.g., /users/:id -> /users/{id})
          openapi_path = path.gsub(/:([a-zA-Z0-9_]+)/, '{\1}')

          ir.openapi_spec['paths'] ||= {}
          ir.openapi_spec['paths'][openapi_path] ||= {}
          ir.openapi_spec['paths'][openapi_path][method] ||= {
            'responses' => { '200' => { 'description' => 'OK' } }
          }

          # Infer path parameters from the route itself
          path.scan(/:([a-zA-Z0-9_]+)/).flatten.each do |param_name|
            ir.openapi_spec['paths'][openapi_path][method]['parameters'] ||= []
            next if ir.openapi_spec['paths'][openapi_path][method]['parameters'].any? { |p| p['name'] == param_name }

            ir.openapi_spec['paths'][openapi_path][method]['parameters'] << {
              'name' => param_name,
              'in' => 'path',
              'required' => true,
              'schema' => { 'type' => 'string' }
            }
          end
        end
      end
    end
  end
end
