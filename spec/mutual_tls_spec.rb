# frozen_string_literal: true

require_relative 'spec_helper'

class MutualTLSTest < Minitest::Test
  def test_emit_mutual_tls
    ir = Cdd::IR.new
    ir.openapi_spec['components'] = {
      'securitySchemes' => {
        'mutualTlsAuth' => {
          'type' => 'mutualTLS',
          'description' => 'Mutual TLS auth'
        }
      }
    }
    out = Cdd::Classes::Emitter.emit(ir)
    assert_match(/# @security_scheme mutualTlsAuth mutualTLS Mutual TLS auth/, out)
  end

  def test_parse_mutual_tls
    code = <<~RUBY
      # @security_scheme mutualTlsAuth mutualTLS Mutual TLS auth
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    sec = ir.openapi_spec['components']['securitySchemes']['mutualTlsAuth']
    assert_equal 'mutualTLS', sec['type']
    assert_equal 'Mutual TLS auth', sec['description']
  end

  def test_emit_discriminator
    ir = Cdd::IR.new
    ir.openapi_spec['components'] = {
      'schemas' => {
        'Pet' => {
          'oneOf' => [
            { '$ref' => '#/components/schemas/Dog' },
            { '$ref' => '#/components/schemas/Cat' }
          ],
          'discriminator' => {
            'propertyName' => 'petType',
            'mapping' => {
              'dog' => '#/components/schemas/Dog',
              'cat' => '#/components/schemas/Cat'
            },
            'defaultMapping' => '#/components/schemas/Dog'
          }
        }
      }
    }

    out = Cdd::Classes::Emitter.emit(ir)
    assert_match(/# @schema_one_of Pet Dog, Cat discriminator:petType mapping:dog:Dog,cat:Cat defaultMapping:Dog/, out)
  end

  def test_parse_discriminator
    code = <<~RUBY
      # @schema_one_of Pet Dog, Cat discriminator:petType mapping:dog:Dog,cat:Cat defaultMapping:Dog
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    schema = ir.openapi_spec['components']['schemas']['Pet']
    assert schema
    assert schema['discriminator']
    assert_equal 'petType', schema['discriminator']['propertyName']
    assert_equal '#/components/schemas/Dog', schema['discriminator']['mapping']['dog']
    assert_equal '#/components/schemas/Cat', schema['discriminator']['mapping']['cat']
    assert_equal '#/components/schemas/Dog', schema['discriminator']['defaultMapping']
  end

  def test_emit_anyof_discriminator
    ir = Cdd::IR.new
    ir.openapi_spec['components'] = {
      'schemas' => {
        'Vehicle' => {
          'anyOf' => [
            { '$ref' => '#/components/schemas/Car' },
            { '$ref' => '#/components/schemas/Truck' }
          ],
          'discriminator' => {
            'propertyName' => 'type',
            'mapping' => {
              'c' => '#/components/schemas/Car',
              't' => '#/components/schemas/Truck'
            }
          }
        }
      }
    }

    out = Cdd::Classes::Emitter.emit(ir)
    assert_match(/# @schema_any_of Vehicle Car, Truck discriminator:type mapping:c:Car,t:Truck/, out)
  end

  def test_parse_anyof_discriminator
    code = <<~RUBY
      # @schema_any_of Vehicle Car, Truck discriminator:type mapping:c:Car,t:Truck
    RUBY
    ir = Cdd::IR.new
    tokens = Ripper.lex(code)
    Cdd::Docstrings::Parser.parse(tokens, ir)

    schema = ir.openapi_spec['components']['schemas']['Vehicle']
    assert schema
    assert schema['discriminator']
    assert_equal 'type', schema['discriminator']['propertyName']
    assert_equal '#/components/schemas/Car', schema['discriminator']['mapping']['c']
  end

  def test_emit_anyof_discriminator_no_mapping
    ir = Cdd::IR.new
    ir.openapi_spec['components'] = {
      'schemas' => {
        'Base' => {
          'anyOf' => [{ '$ref' => '#/components/schemas/A' }],
          'discriminator' => { 'propertyName' => 'type' }
        }
      }
    }
    out = Cdd::Classes::Emitter.emit(ir)
    assert_match(/# @schema_any_of Base A discriminator:type/, out)
  end

  def test_emit_anyof_discriminator_default_mapping
    ir = Cdd::IR.new
    ir.openapi_spec['components'] = {
      'schemas' => {
        'Base' => {
          'anyOf' => [{ '$ref' => '#/components/schemas/A' }],
          'discriminator' => {
            'propertyName' => 'type',
            'mapping' => { 'a' => '#/components/schemas/A' },
            'defaultMapping' => '#/components/schemas/A'
          }
        }
      }
    }
    out = Cdd::Classes::Emitter.emit(ir)
    assert_match(/# @schema_any_of Base A discriminator:type mapping:a:A defaultMapping:A/, out)
  end
end
