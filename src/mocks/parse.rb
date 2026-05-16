# frozen_string_literal: true

require 'json'

# Documentation for Cdd
module Cdd
  # Module for mocks handling
  module Mocks
    # Parser for mocks
    class Parser
      # Parses mocks from tokens and adds to ir
      # @param tokens [Array] tokens array
      # @param ir [Cdd::IR] Intermediate Representation
      def self.parse(tokens, ir)
        in_mock = false
        schema = nil
        example_name = nil
        mock_body = ''

        infer_schema = lambda do |val|
          case val
          when String then { 'type' => 'string' }
          when Integer then { 'type' => 'integer' }
          when Float then { 'type' => 'number' }
          when TrueClass, FalseClass then { 'type' => 'boolean' }
          when Array
            if val.empty?
              { 'type' => 'array',
                'items' => {} }
            else
              { 'type' => 'array', 'items' => infer_schema.call(val.first) }
            end
          when Hash
            props = {}
            val.each { |k, v| props[k] = infer_schema.call(v) }
            { 'type' => 'object', 'properties' => props }
          else
            {}
          end
        end

        process_mock = lambda do
          parsed = JSON.parse(mock_body)
          ir.openapi_spec['components'] ||= {}
          ir.openapi_spec['components']['examples'] ||= {}
          ir.openapi_spec['components']['examples'][example_name] = {
            'summary' => "Example for #{schema}",
            'value' => parsed
          }
          ir.openapi_spec['components']['schemas'] ||= {}
          ir.openapi_spec['components']['schemas'][schema] ||= { 'type' => 'object', 'properties' => {} }
          inferred = infer_schema.call(parsed)
          inferred['properties']&.each do |k, v|
            ir.openapi_spec['components']['schemas'][schema]['properties'][k] = v
          end
        rescue JSON::ParserError
          # ignored
        end

        tokens.each do |token|
          if token[1] == :on_comment
            if token[2] =~ /#\s*@mock\s+\[(\w+)\]\s+(\w+)/
              process_mock.call if in_mock
              in_mock = true
              schema = ::Regexp.last_match(1)
              example_name = ::Regexp.last_match(2)
              mock_body = ''
            elsif token[2] =~ /#\s*@example_external\s+\[(\w+)\]\s+(\w+)\s+(.*)/
              process_mock.call if in_mock
              in_mock = false
              schema = ::Regexp.last_match(1)
              ex_name = ::Regexp.last_match(2)
              ext_url = ::Regexp.last_match(3).strip
              ir.openapi_spec['components'] ||= {}
              ir.openapi_spec['components']['examples'] ||= {}
              ir.openapi_spec['components']['examples'][ex_name] = {
                'summary' => "Example for #{schema}",
                'externalValue' => ext_url
              }

            elsif in_mock
              mock_body += token[2].sub(/^#\s?/, '')
            end
          elsif in_mock && !token[2].strip.empty?
            process_mock.call
            in_mock = false
          end
        end
        process_mock.call if in_mock
      end
    end
  end
end
