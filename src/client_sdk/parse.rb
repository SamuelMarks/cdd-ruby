# frozen_string_literal: true

require_relative '../arazzo/parse'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Client SDK generation and parsing module.
  module ClientSdk
    # Parser for extracting OpenAPI paths, operationIds, and Arazzo workflows from generated ClientSdk code.
    class Parser
      # Internal SDK helper method names that do not correspond to OpenAPI endpoints.
      INTERNAL_SDK_METHODS = %w[initialize authorize_oauth2 mcp auth workflows].freeze

      # HTTP verbs recognized on `Net::HTTP::<Verb>` constants.
      NET_HTTP_CONSTS = %w[Get Post Put Delete Patch Options Head Trace].freeze

      # Parses `ClientSdk` method definitions and Arazzo workflows from Ripper tokens and populates the IR.
      #
      # @param tokens [Array<Array>] Ripper lexed token array
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.parse(tokens, ir)
        Cdd::Arazzo::Parser.parse(tokens, ir)
        current_class_name = nil
        current_def = false
        op_id = nil

        tokens.each_with_index do |token, idx|
          if token[1] == :on_kw && token[2] == 'class'
            next_const = tokens[(idx + 1)..(idx + 5)].find { |t| t[1] == :on_const }
            current_class_name = next_const[2]
          elsif token[1] == :on_kw && token[2] == 'def' && current_class_name == 'ClientSdk'
            op_id, current_def = handle_sdk_def(tokens, idx, ir)
          elsif token[1] == :on_ident && token[2] == 'req_path' && current_def
            current_def, op_id = handle_req_path(tokens, idx, op_id, ir)
          end
        end
      end

      # Handles a `def` token inside `ClientSdk` and registers a default fallback operation.
      #
      # @param tokens [Array<Array>] Ripper token stream
      # @param idx [Integer] index of `def` token
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [Array(String, Boolean)] `[op_id, current_def]`
      def self.handle_sdk_def(tokens, idx, ir)
        next_ident = tokens[(idx + 1)..(idx + 5)].find { |t| %i[on_ident on_kw].include?(t[1]) }
        op_id = next_ident[2]
        unless INTERNAL_SDK_METHODS.include?(op_id) || op_id.start_with?('handle_webhook_')
          ir.openapi_spec['paths'] ||= {}
          ir.openapi_spec['paths']["/#{op_id}"] ||= { 'get' => { 'operationId' => op_id } }
        end
        [op_id, true]
      end

      # Extracts the `req_path` string literal and HTTP method constant inside an SDK method body.
      #
      # @param tokens [Array<Array>] Ripper token stream
      # @param idx [Integer] index of `req_path` token
      # @param op_id [String] current operation ID
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [Array(Boolean, nil)] `[false, nil]` once resolved
      def self.handle_req_path(tokens, idx, op_id, ir)
        tstring = tokens[(idx + 3)..(idx + 10)].find { |t| t[1] == :on_tstring_content }
        http_method = detect_net_http_method(tokens[(idx + 1)..])
        path_str = tstring[2]

        ir.openapi_spec['paths'] ||= {}
        ir.openapi_spec['paths'].delete("/#{op_id}")
        ir.openapi_spec['paths'][path_str] ||= {}
        ir.openapi_spec['paths'][path_str][http_method] = { 'operationId' => op_id }
        [false, nil]
      end

      # Scans forward until the next `def` to find a `Net::HTTP::<Method>` constant.
      #
      # @param slice [Array<Array>] subsequent Ripper tokens
      # @return [String] lowercase HTTP method name (default `'get'`)
      def self.detect_net_http_method(slice)
        found = slice.find { |tok| tok[1] == :on_const && NET_HTTP_CONSTS.include?(tok[2]) }
        found[2].downcase
      end
    end
  end
end
