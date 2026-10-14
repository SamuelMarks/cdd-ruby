# frozen_string_literal: true

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for parsing and emitting API client functions.
  module Functions
    # Parser for extracting API client methods and parameters from Ripper tokens.
    class Parser
      # Parses `ApiClient` methods from tokens and populates the IR.
      #
      # @param tokens [Array<Array>] Ripper lexed token array
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.parse(tokens, ir)
        state = { in_api_client: false, in_method: false, method: nil, path: nil }
        tokens.each_with_index do |token, idx|
          step_function_token(tokens, token, idx, state, ir)
        end
      end

      # Advances the `Functions::Parser` state machine by one token.
      #
      # @param tokens [Array<Array>] Ripper token stream
      # @param token [Array] current Ripper token
      # @param idx [Integer] current token index
      # @param state [Hash] mutable parser state
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.step_function_token(tokens, token, idx, state, ir)
        if token[1] == :on_kw && token[2] == 'class'
          name_token = tokens[(idx + 1)..].find { |t| t[1] == :on_const }
          state[:in_api_client] = !name_token.nil? && name_token[2] == 'ApiClient'
        elsif token[1] == :on_comment && token[2] =~ /#\s*@api_client\s+([A-Z]+)\s+(\S+)/
          state[:method] = ::Regexp.last_match(1).downcase
          state[:path] = ::Regexp.last_match(2)
          register_client_endpoint(ir, state[:path], state[:method])
        elsif state[:in_api_client] && token[1] == :on_kw && token[2] == 'def'
          state[:in_method] = true
          parse_method_signature(tokens, idx, ir, state[:path], state[:method])
        elsif state[:in_api_client] && token[1] == :on_kw && token[2] == 'end'
          if state[:in_method]
            state[:in_method] = false
          else
            state[:in_api_client] = false
          end
        end
      end

      # Registers an endpoint path and HTTP method in the IR.
      #
      # @param ir [Cdd::IR] Intermediate Representation
      # @param path [String] endpoint path
      # @param http_method [String] lowercase HTTP method
      # @return [void]
      def self.register_client_endpoint(ir, path, http_method)
        ir.openapi_spec['paths'] ||= {}
        ir.openapi_spec['paths'][path] ||= {}
        ir.openapi_spec['paths'][path][http_method] ||= {
          'responses' => { '200' => { 'description' => 'OK' } }
        }
      end

      # Extracts keyword arguments from a `def` signature and attaches them to the current operation.
      #
      # @param tokens [Array<Array>] Ripper token stream
      # @param idx [Integer] index of the `def` token
      # @param ir [Cdd::IR] Intermediate Representation
      # @param http_path [String, nil] current endpoint path
      # @param http_method [String, nil] current HTTP method
      # @return [void]
      def self.parse_method_signature(tokens, idx, ir, http_path, http_method)
        cursor = idx + 1
        while tokens[cursor] && tokens[cursor][1] != :on_nl
          if tokens[cursor][1] == :on_label && http_path && http_method
            op = ir.openapi_spec.dig('paths', http_path, http_method)
            attach_argument_to_operation(op, http_path, tokens[cursor][2].sub(':', ''))
          end
          cursor += 1
        end
      end

      # Attaches a parsed method keyword argument to the OpenAPI operation hash.
      #
      # @param op [Hash] OpenAPI operation hash
      # @param http_path [String] OpenAPI route path
      # @param arg_name [String] method parameter name
      # @return [void]
      def self.attach_argument_to_operation(op, http_path, arg_name)
        if arg_name == 'body'
          op['requestBody'] ||= { 'content' => { 'application/json' => {} } }
        else
          op['parameters'] ||= []
          return if op['parameters'].any? { |p| p['name'] == arg_name }

          in_loc = http_path.include?("{#{arg_name}}") ? 'path' : 'query'
          op['parameters'] << { 'name' => arg_name, 'in' => in_loc }
        end
      end
    end
  end
end
