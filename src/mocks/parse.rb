# frozen_string_literal: true

require 'json'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for parsing and emitting OpenAPI example mock comments.
  module Mocks
    # Parser for extracting `@mock` and `@example_external` blocks from Ripper tokens.
    class Parser
      # Parses `@mock` and `@example_external` comments from tokens and populates the IR.
      #
      # @param tokens [Array<Array>] Ripper lexed token array
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.parse(tokens, ir)
        state = { in_mock: false, schema: nil, example_name: nil, body: '' }
        tokens.each do |token|
          if token[1] == :on_comment
            handle_mock_comment(token[2], state, ir)
          elsif state[:in_mock] && !token[2].strip.empty?
            flush_mock(state, ir)
          end
        end
        flush_mock(state, ir) if state[:in_mock]
      end

      # Handles a single comment line while scanning for `@mock` or `@example_external`.
      #
      # @param comment [String] raw comment text
      # @param state [Hash] mutable mock scanner state
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.handle_mock_comment(comment, state, ir)
        if comment =~ /#\s*@mock\s+\[(\w+)\]\s+(\w+)/
          flush_mock(state, ir) if state[:in_mock]
          state[:in_mock] = true
          state[:schema] = ::Regexp.last_match(1)
          state[:example_name] = ::Regexp.last_match(2)
          state[:body] = ''
        elsif comment =~ /#\s*@example_external\s+\[(\w+)\]\s+(\w+)\s+(.*)/
          flush_mock(state, ir) if state[:in_mock]
          register_external_example(::Regexp.last_match(1), ::Regexp.last_match(2),
                                    ::Regexp.last_match(3).strip, ir)
        elsif state[:in_mock]
          state[:body] += comment.sub(/^#\s?/, '')
        end
      end

      # Registers an `@example_external` entry in `components.examples`.
      #
      # @param schema [String] associated schema name
      # @param ex_name [String] example key name
      # @param ext_url [String] external example URL
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.register_external_example(schema, ex_name, ext_url, ir)
        ir.mocks |= [ex_name]
        ir.openapi_spec['components'] ||= {}
        ir.openapi_spec['components']['examples'] ||= {}
        ir.openapi_spec['components']['examples'][ex_name] = {
          'summary' => "Example for #{schema}",
          'externalValue' => ext_url
        }
      end

      # Parses the accumulated JSON mock body and populates `components.examples` and `components.schemas`.
      #
      # @param state [Hash] mutable mock scanner state
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.flush_mock(state, ir)
        state[:in_mock] = false
        parsed = JSON.parse(state[:body])
        ir.mocks |= [state[:example_name]]
        ir.openapi_spec['components'] ||= {}
        ir.openapi_spec['components']['examples'] ||= {}
        ir.openapi_spec['components']['examples'][state[:example_name]] = {
          'summary' => "Example for #{state[:schema]}",
          'value' => parsed
        }
        ir.openapi_spec['components']['schemas'] ||= {}
        ir.openapi_spec['components']['schemas'][state[:schema]] ||= { 'type' => 'object', 'properties' => {} }
        inferred = infer_schema(parsed)
        inferred['properties']&.each do |k, v|
          ir.openapi_spec['components']['schemas'][state[:schema]]['properties'][k] = v
        end
      rescue JSON::ParserError
        nil
      end

      # Infers an OpenAPI JSON Schema hash from a parsed Ruby value.
      #
      # @param val [Object] parsed JSON value
      # @return [Hash{String => Object}] inferred schema definition
      def self.infer_schema(val)
        case val
        when String then { 'type' => 'string' }
        when Integer then { 'type' => 'integer' }
        when Float then { 'type' => 'number' }
        when TrueClass, FalseClass then { 'type' => 'boolean' }
        when Array
          val.empty? ? { 'type' => 'array', 'items' => {} } : { 'type' => 'array', 'items' => infer_schema(val.first) }
        when Hash
          { 'type' => 'object', 'properties' => val.transform_values { |v| infer_schema(v) } }
        else
          {}
        end
      end
    end
  end
end
