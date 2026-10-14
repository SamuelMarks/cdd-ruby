# frozen_string_literal: true

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Client SDK CLI generation and parsing module.
  module ClientSdkCli
    # Parser for extracting OpenAPI paths and operationIds from generated CLI scripts.
    class Parser
      # Parses CLI `case command` branches from Ripper tokens and populates the IR.
      #
      # @param tokens [Array<Array>] Ripper lexed token array
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.parse(tokens, ir)
        state = { in_cli_case: false, nesting: 0, in_when: false }
        tokens.each_with_index do |token, idx|
          step_cli_token(tokens, token, idx, state, ir)
        end
      end

      # Advances the CLI parser state machine by one token.
      #
      # @param tokens [Array<Array>] Ripper token stream
      # @param token [Array] current Ripper token
      # @param idx [Integer] current token index
      # @param state [Hash] mutable state hash
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.step_cli_token(tokens, token, idx, state, ir)
        if token[1] == :on_kw
          handle_cli_keyword(tokens, token[2], idx, state)
        elsif token[1] == :on_tstring_content && state[:in_when]
          register_when_operation(tokens, idx, token[2], ir) unless token[2] == 'mcp'
          state[:in_when] = false
        end
      end

      # Handles `case`, `end`, and `when` keywords in `ClientSdkCli::Parser`.
      #
      # @param tokens [Array<Array>] Ripper token stream
      # @param keyword [String] keyword string
      # @param idx [Integer] token index
      # @param state [Hash] mutable state hash
      # @return [void]
      def self.handle_cli_keyword(tokens, keyword, idx, state)
        case keyword
        when 'case'
          state[:nesting] += 1
          next_ident = tokens[(idx + 1)..(idx + 5)].find { |t| t[1] == :on_ident }
          state[:in_cli_case] = true if next_ident && next_ident[2] == 'command'
        when 'end'
          return unless state[:nesting].positive?

          state[:in_cli_case] = false if state[:in_cli_case] && state[:nesting] == 1
          state[:nesting] -= 1
        when 'when'
          state[:in_when] = true if state[:in_cli_case]
        end
      end

      # Registers an operation extracted from a CLI `when '<op_id>'` branch.
      #
      # @param tokens [Array<Array>] Ripper token stream
      # @param idx [Integer] index of the operationId string token
      # @param op_id [String] operationId string
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.register_when_operation(tokens, idx, op_id, ir)
        http_method = 'get'
        path_str = "/#{op_id}"

        tokens[idx..(idx + 20)].each do |tok|
          next unless tok[1] == :on_tstring_content && tok[2].start_with?('Calling ')

          parts = tok[2].split
          http_method = parts[1].downcase
          path_str = parts[2]
          break
        end

        ir.openapi_spec['paths'] ||= {}
        ir.openapi_spec['paths'][path_str] ||= {}
        ir.openapi_spec['paths'][path_str][http_method] = { 'operationId' => op_id }
      end
    end
  end
end
