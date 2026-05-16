# frozen_string_literal: true

# Documentation for Cdd
module Cdd
  # Module for classes handling
  module Classes
    # Parser for classes
    class Parser
      # Parses classes from tokens and adds to ir
      # @param tokens [Array] tokens array
      # @param ir [Cdd::IR] Intermediate Representation
      def self.parse(tokens, ir)
        current_class = nil
        tokens.each_with_index do |token, i|
          if token[1] == :on_comment
            comment = token[2]
            if comment =~ /#\s*@(schema_one_of|schema_any_of)\s+(\w+)\s+(.+)/
              type = ::Regexp.last_match(1) == 'schema_one_of' ? 'oneOf' : 'anyOf'
              name = ::Regexp.last_match(2)
              rest = ::Regexp.last_match(3).strip

              parts = rest.split(/\s+/)
              refs_part = parts.shift
              refs = refs_part.split(',').map { |r| { '$ref' => "#/components/schemas/#{r.strip}" } }

              schema = { type => refs }

              discriminator = nil
              parts.each do |part|
                if part.start_with?('discriminator:')
                  discriminator ||= {}
                  discriminator['propertyName'] = part.split(':', 2).last
                elsif part.start_with?('mapping:')
                  discriminator ||= {}
                  mapping_str = part.split(':', 2).last
                  mapping = {}
                  mapping_str.split(',').each do |pair|
                    k, v = pair.split(':')
                    mapping[k] = "#/components/schemas/#{v}"
                  end
                  discriminator['mapping'] = mapping
                elsif part.start_with?('defaultMapping:')
                  discriminator ||= {}
                  discriminator['defaultMapping'] = "#/components/schemas/#{part.split(':', 2).last}"
                end
              end

              schema['discriminator'] = discriminator if discriminator

              ir.openapi_spec['components'] ||= {}
              ir.openapi_spec['components']['schemas'] ||= {}
              ir.openapi_spec['components']['schemas'][name] = schema
            end
          elsif token[1] == :on_kw && token[2] == 'class'
            name_token = tokens[i + 1..].find { |t| t[1] == :on_const }
            if name_token
              name = name_token[2]
              ir.classes << name
              current_class = name

              ir.openapi_spec['components'] ||= {}
              ir.openapi_spec['components']['schemas'] ||= {}
              ir.openapi_spec['components']['schemas'][name] ||= { 'type' => 'object', 'properties' => {} }

              # check for inheritance / allOf
              j = i + 1
              parent = nil
              while j < tokens.size && tokens[j][1] != :on_nl && tokens[j][1] != :on_kw
                if tokens[j][1] == :on_op && tokens[j][2] == '<'
                  parent_token = tokens[j + 1..].find { |t| t[1] == :on_const }
                  parent = parent_token[2] if parent_token
                  break
                end
                j += 1
              end

              if parent
                ir.openapi_spec['components']['schemas'][name]['allOf'] = [
                  { '$ref' => "#/components/schemas/#{parent}" }
                ]
              end
            end
          elsif token[1] == :on_ident && token[2] == 'attr_accessor' && current_class
            j = i + 1
            while j < tokens.size && tokens[j][1] != :on_nl
              if tokens[j][1] == :on_symbeg && tokens[j + 1] && tokens[j + 1][1] == :on_ident
                prop = tokens[j + 1][2]
                ir.openapi_spec['components'] ||= {}
                ir.openapi_spec['components']['schemas'] ||= {}
                ir.openapi_spec['components']['schemas'][current_class] ||= { 'type' => 'object', 'properties' => {} }
                ir.openapi_spec['components']['schemas'][current_class]['properties'] ||= {}
                ir.openapi_spec['components']['schemas'][current_class]['properties'][prop] ||= { 'type' => 'string' }
              end
              j += 1
            end
          end
        end
      end
    end
  end
end
