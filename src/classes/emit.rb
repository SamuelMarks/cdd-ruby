# frozen_string_literal: true

# Documentation for Cdd
module Cdd
  # Module for classes handling
  module Classes
    # Emitter for classes
    class Emitter
      # Emits classes from ir
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [String] generated output
      def self.emit(ir)
        out = ''

        security_schemes = ir.openapi_spec.dig('components', 'securitySchemes') || {}
        security_schemes.each do |name, scheme|
          opts = []
          scheme.each do |k, v|
            next if %w[type description].include?(k)

            opts << "#{k}:#{v}"
          end
          opts_str = opts.empty? ? '' : " #{opts.join(' ')}"
          desc = scheme['description'] ? " #{scheme['description']}" : ''
          out += "# @security_scheme #{name} #{scheme['type']}#{opts_str}#{desc}\n"
        end

        out += "\n" unless security_schemes.empty?

        schemas = ir.openapi_spec.dig('components', 'schemas') || {}
        schemas.each do |name, schema|
          if schema['oneOf']
            refs = schema['oneOf'].map { |r| r['$ref'].split('/').last }.join(', ')
            if schema['discriminator']
              prop = schema['discriminator']['propertyName']
              mapping = schema['discriminator']['mapping']
              if mapping
                mapping_str = mapping.map { |k, v| "#{k}:#{v.split('/').last}" }.join(',')
                if schema['discriminator']['defaultMapping']
                  dm = schema['discriminator']['defaultMapping'].split('/').last
                  out += "# @schema_one_of #{name} #{refs} discriminator:#{prop} mapping:#{mapping_str} defaultMapping:#{dm}\n"
                else
                  out += "# @schema_one_of #{name} #{refs} discriminator:#{prop} mapping:#{mapping_str}\n"
                end

              else
                out += "# @schema_one_of #{name} #{refs} discriminator:#{prop}\n"
              end
            else
              out += "# @schema_one_of #{name} #{refs}\n"
            end

          elsif schema['anyOf']
            refs = schema['anyOf'].map { |r| r['$ref'].split('/').last }.join(', ')
            if schema['discriminator']
              prop = schema['discriminator']['propertyName']
              mapping = schema['discriminator']['mapping']
              if mapping
                mapping_str = mapping.map { |k, v| "#{k}:#{v.split('/').last}" }.join(',')
                if schema['discriminator']['defaultMapping']
                  dm = schema['discriminator']['defaultMapping'].split('/').last
                  out += "# @schema_any_of #{name} #{refs} discriminator:#{prop} mapping:#{mapping_str} defaultMapping:#{dm}\n"
                else
                  out += "# @schema_any_of #{name} #{refs} discriminator:#{prop} mapping:#{mapping_str}\n"
                end
              else
                out += "# @schema_any_of #{name} #{refs} discriminator:#{prop}\n"
              end
            else
              out += "# @schema_any_of #{name} #{refs}\n"
            end

          else
            opts = []
            schema.each do |k, v|
              next if %w[type properties description allOf xml].include?(k)

              opts << "#{k}:#{v}" if v.is_a?(String) || v == true || v == false
            end
            opts_str = opts.empty? ? '' : " #{opts.join(' ')}"
            desc = schema['description'] ? " #{schema['description']}" : ''
            out += "# @schema #{name}#{opts_str}#{desc}\n"
            if schema['xml']
              xml_opts = []
              schema['xml'].each { |xk, xv| xml_opts << "#{xk}:#{xv}" }
              out += "# @schema_xml #{name} #{xml_opts.join(' ')}\n"
            end

            if schema['allOf'].is_a?(Array)
              # Find the first ref to represent parent inheritance
              ref = schema['allOf'].find { |a| a['$ref'] }
              parent = ref['$ref'].split('/').last if ref
              out += "class #{name} < #{parent}\n"
            else
              out += "class #{name}\n"
            end

            schema['properties']&.each_key do |prop|
              out += "  attr_accessor :#{prop}\n"
            end
            out += "end\n\n"
          end
        end
        out
      end
    end
  end
end
