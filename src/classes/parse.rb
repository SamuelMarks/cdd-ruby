# frozen_string_literal: true

require_relative '../token_scanner'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for parsing and emitting Ruby model classes and OpenAPI schemas.
  module Classes
    # Parser for extracting Ruby model classes and properties into the IR.
    class Parser
      # Parses classes and schema annotations from tokens and populates the IR.
      #
      # @param tokens [Array<Array>] Ripper lexed token array
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.parse(tokens, ir)
        current_class = nil
        tokens.each_with_index do |token, idx|
          case token[1]
          when :on_comment
            parse_class_comment(token[2], current_class, ir)
          when :on_kw
            current_class = parse_class_declaration(tokens, idx, ir) if token[2] == 'class'
          when :on_ident
            parse_attr_accessor(tokens, idx, current_class, ir) if token[2] == 'attr_accessor' && current_class
          end
        end
      end

      # Parses `@schema_one_of`, `@schema_any_of`, `@readonly`, or `# property:` comments.
      #
      # @param comment [String] raw comment text
      # @param current_class [String, nil] currently active class name
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.parse_class_comment(comment, current_class, ir)
        if comment =~ /#\s*@(schema_one_of|schema_any_of)\s+(\w+)\s+(.+)/
          comp_key = ::Regexp.last_match(1) == 'schema_one_of' ? 'oneOf' : 'anyOf'
          name = ::Regexp.last_match(2)
          schema = Cdd::TokenScanner.parse_composition_schema(comp_key, ::Regexp.last_match(3))
          ensure_schemas(ir)[name] = schema
        elsif current_class && comment =~ /#\s*@readonly\s+(\w+)/
          prop = ::Regexp.last_match(1)
          schema = ensure_class_schema(ir, current_class)
          (schema['properties'][prop] ||= { 'type' => 'string' })['readOnly'] = true
        elsif current_class && comment =~ /#\s*property:\s+(\w+)\s+\((.+)\)/
          prop = ::Regexp.last_match(1)
          type = ::Regexp.last_match(2)
          schema = ensure_class_schema(ir, current_class)
          schema['properties'][prop] = { 'type' => type }
        end
      end

      # Parses a `class Name < Parent` declaration and registers it if it is a domain model.
      #
      # @param tokens [Array<Array>] Ripper token stream
      # @param idx [Integer] index of the `class` keyword token
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [String, nil] the parsed domain class name or nil if scaffolding/anonymous
      def self.parse_class_declaration(tokens, idx, ir)
        name_token = tokens[(idx + 1)..].find { |t| t[1] == :on_const || (t[1] == :on_op && t[2] == '<<') }
        return nil unless name_token && name_token[1] == :on_const

        name = name_token[2]
        return nil if Cdd::TokenScanner.scaffolding_class?(name)

        ir.classes << name
        schema = ensure_class_schema(ir, name)
        parent = extract_parent_class(tokens, idx)
        schema['allOf'] = [{ '$ref' => "#/components/schemas/#{parent}" }] if parent
        name
      end

      # Extracts the parent constant name from a `class Child < Parent` header line.
      #
      # @param tokens [Array<Array>] Ripper token stream
      # @param idx [Integer] index of the `class` token
      # @return [String, nil] parent class name or nil
      def self.extract_parent_class(tokens, idx)
        cursor = idx + 1
        while cursor < tokens.size && tokens[cursor][1] != :on_nl && tokens[cursor][1] != :on_kw
          if tokens[cursor][1] == :on_op && tokens[cursor][2] == '<'
            parent_token = tokens[(cursor + 1)..].find { |t| %i[on_const on_nl].include?(t[1]) }
            return parent_token[2] if parent_token && parent_token[1] == :on_const

            return nil
          end
          cursor += 1
        end
        nil
      end

      # Parses `attr_accessor :prop1, :prop2` declarations inside a domain model class.
      #
      # @param tokens [Array<Array>] Ripper token stream
      # @param idx [Integer] index of `attr_accessor` token
      # @param current_class [String] active domain class name
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.parse_attr_accessor(tokens, idx, current_class, ir)
        cursor = idx + 1
        while cursor < tokens.size && tokens[cursor][1] != :on_nl
          if tokens[cursor][1] == :on_symbeg && tokens[cursor + 1] && tokens[cursor + 1][1] == :on_ident
            prop = tokens[cursor + 1][2]
            schema = ensure_class_schema(ir, current_class)
            schema['properties'][prop] ||= { 'type' => 'string' }
          end
          cursor += 1
        end
      end

      # Ensures `components.schemas` hash exists on the IR and returns it.
      #
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [Hash] the schemas hash
      def self.ensure_schemas(ir)
        ir.openapi_spec['components'] ||= {}
        ir.openapi_spec['components']['schemas'] ||= {}
      end

      # Ensures an object schema entry with a `properties` hash exists for `class_name`.
      #
      # @param ir [Cdd::IR] Intermediate Representation
      # @param class_name [String] model class name
      # @return [Hash] the class schema hash
      def self.ensure_class_schema(ir, class_name)
        schemas = ensure_schemas(ir)
        schemas[class_name] ||= { 'type' => 'object', 'properties' => {} }
        schemas[class_name]['properties'] ||= {}
        schemas[class_name]
      end
    end
  end
end
