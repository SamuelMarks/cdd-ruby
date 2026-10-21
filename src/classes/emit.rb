# frozen_string_literal: true

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for parsing and emitting Ruby model classes and OpenAPI schemas.
  module Classes
    # Emitter for generating Ruby class definitions and OpenAPI schema docstrings from the IR.
    class Emitter
      # Emits security scheme tags and Ruby model class definitions from the IR.
      #
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [String] generated Ruby source code
      def self.emit(ir)
        out = emit_security_schemes(ir.openapi_spec.dig('components', 'securitySchemes') || {})
        raw_schemas = ir.openapi_spec.dig('components', 'schemas') || {}
        ir.typed_schemas.each do |schema|
          out += if schema.one_of
                   emit_composition_schema('schema_one_of', schema.name, schema.one_of, schema.discriminator)
                 elsif schema.any_of
                   emit_composition_schema('schema_any_of', schema.name, schema.any_of, schema.discriminator)
                 else
                   emit_object_schema(schema, raw_schemas[schema.name] || {})
                 end
        end
        out
      end

      # Emits `@security_scheme` docstring tags for all component security schemes.
      #
      # @param security_schemes [Hash{String => Hash}] securitySchemes component map
      # @return [String] formatted `@security_scheme` lines
      def self.emit_security_schemes(security_schemes)
        return '' if security_schemes.empty?

        lines = security_schemes.map do |name, scheme|
          opts = []
          scheme.each do |k, v|
            next if %w[type description].include?(k)

            opts << "#{k}:#{v}"
          end
          opts_str = opts.empty? ? '' : " #{opts.join(' ')}"
          desc = scheme['description'] ? " #{scheme['description']}" : ''
          "# @security_scheme #{name} #{scheme['type']}#{opts_str}#{desc}\n"
        end
        "#{lines.join}\n"
      end

      # Emits a `@schema_one_of` or `@schema_any_of` docstring tag with optional discriminator metadata.
      #
      # @param tag_name [String] `'schema_one_of'` or `'schema_any_of'`
      # @param name [String] schema component name
      # @param refs_array [Array<Hash>] array of `$ref` objects
      # @param discriminator [Hash, nil] optional discriminator object
      # @return [String] formatted composition schema docstring line
      def self.emit_composition_schema(tag_name, name, refs_array, discriminator)
        refs = refs_array.map { |r| r['$ref'].split('/').last }.join(', ')
        return "# @#{tag_name} #{name} #{refs}\n" unless discriminator

        prop = discriminator['propertyName']
        mapping = discriminator['mapping']
        return "# @#{tag_name} #{name} #{refs} discriminator:#{prop}\n" unless mapping

        mapping_str = mapping.map { |k, v| "#{k}:#{v.split('/').last}" }.join(',')
        if discriminator['defaultMapping']
          dm = discriminator['defaultMapping'].split('/').last
          "# @#{tag_name} #{name} #{refs} discriminator:#{prop} mapping:#{mapping_str} defaultMapping:#{dm}\n"
        else
          "# @#{tag_name} #{name} #{refs} discriminator:#{prop} mapping:#{mapping_str}\n"
        end
      end

      # Emits a Ruby class definition and its `@schema` / `@schema_xml` docstrings from a typed `Cdd::IR::Schema`.
      #
      # @param schema [Cdd::IR::Schema] typed OpenAPI schema value object
      # @param raw_schema [Hash] raw OpenAPI schema hash for additional vendor/scalar options
      # @return [String] formatted Ruby class source code
      def self.emit_object_schema(schema, raw_schema)
        opts = []
        raw_schema.each do |k, v|
          next if %w[type properties description allOf xml].include?(k)

          opts << "#{k}:#{v}" if v.is_a?(String) || v == true || v == false
        end
        opts_str = opts.empty? ? '' : " #{opts.join(' ')}"
        desc = schema.description ? " #{schema.description}" : ''
        out = "# @schema #{schema.name}#{opts_str}#{desc}\n"
        if schema.xml
          xml_opts = schema.xml.map { |xk, xv| "#{xk}:#{xv}" }
          out += "# @schema_xml #{schema.name} #{xml_opts.join(' ')}\n"
        end
        out += format_class_header(schema.name, schema.all_of)
        schema.properties.each { |prop| out += "  attr_accessor :#{prop.name}\n" }
        "#{out}end\n\n"
      end

      # Formats the `class Name` or `class Name < Parent` header line.
      #
      # @param name [String] class name
      # @param all_of [Array<Hash>, nil] optional `allOf` inheritance array
      # @return [String] class header line
      def self.format_class_header(name, all_of)
        return "class #{name}\n" unless all_of.is_a?(Array)

        ref = all_of.find { |a| a['$ref'] }
        parent = ref['$ref'].split('/').last if ref
        "class #{name} < #{parent}\n"
      end
    end
  end
end
