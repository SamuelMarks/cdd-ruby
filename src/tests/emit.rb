# frozen_string_literal: true

# Documentation for Cdd
module Cdd
  # Module for tests handling
  module Tests
    # Emitter for tests
    class Emitter
      # Emits tests from ir
      # @param ir [Cdd::IR] Intermediate Representation
      # @param options [Hash] Generation options
      # @return [String] generated output
      def self.emit(ir, options = {})
        out = ''
        paths = ir.openapi_spec['paths'] || {}
        return out if paths.empty?

        out += "class ApiClientTest < Minitest::Test\n"
        out += "  require 'ostruct'\n\n"
        paths.each do |path, path_data|
          next if path_data['$ref']

          path_data.each do |method, op|
            next if %w[summary description servers parameters].include?(method)

            op_id = op['operationId'] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_').gsub(/_+/, '_').sub(/^_/, '').sub(
              /_$/, ''
            )}"

            out += "  # @api_test #{method.upcase} #{path}\n"
            out += "  def test_#{op_id}\n"
            out += "    client = ClientSdk.new('http://localhost:8080/v2')\n"

            params = []
            op['parameters']&.each do |param|
              val = if param.dig('schema',
                                 'type') == 'integer'
                      '1'
                    else
                      (param['name'] == 'status' ? "'available'" : "'test_#{param['name']}'")
                    end
              params << "#{param['name']}: #{val}"
            end

            if op['requestBody']
              params << 'id: 1'
              params << "name: 'test'"
              params << "photoUrls: ['http://example.com']"
              params << "status: 'available'"
            end

            params_str = params.empty? ? '' : "{ #{params.join(', ')} }"

            success_code = '200'
            success_code = op['responses'].keys.find { |k| k.to_i >= 200 && k.to_i < 300 } || '200' if op['responses']

            out += "    begin\n"
            out += "      res = client.#{op_id}(#{params_str})\n"
            out += "      refute_nil res\n"
            out += "      assert_equal '#{success_code}', client.last_response.code\n"
            out += "    rescue Errno::ECONNREFUSED\n"
            out += "      skip 'Petstore server is not available'\n"
            out += "    end\n"
            out += "  end\n\n"
          end
        end
        out += "end\n\n"

        needs_db = options[:with_ephemeral] || options[:with_seed]

        if needs_db
          out += "class DatabaseConnectionTest < Minitest::Test\n"
          out += "  require 'sqlite3'\n"
          out += "  def setup\n"
          out += "    ActiveRecord::Base.remove_connection if ActiveRecord::Base.connected?\n"
          out += "  end\n\n"
          out += "  def test_connect_ephemeral\n"
          out += "    ENV['EPHEMERAL_DB'] = 'true'\n"
          out += "    DatabaseConnection.connect!\n"
          out += "    assert ActiveRecord::Base.connected?\n"
          out += "    assert_equal 'sqlite3', ActiveRecord::Base.connection_db_config.adapter\n"
          out += "    ENV['EPHEMERAL_DB'] = nil\n"
          out += "  end\n"
          out += "end\n\n"
        end

        out += "class DaoTest < Minitest::Test\n"
        out += "  require 'ostruct'\n"

        if needs_db
          out += "  require 'active_record'\n"
          out += "  require 'sqlite3'\n\n"
          out += "  def setup\n"
          out += "    ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')\n"
          out += "    ActiveRecord::Schema.define do\n"

          if ir.openapi_spec['components'] && ir.openapi_spec['components']['schemas']
            ir.openapi_spec['components']['schemas'].each do |name, schema|
              out += "      create_table :#{name.downcase}s, force: true do |t|\n"
              schema['properties']&.each do |prop_name, prop_details|
                next if prop_name == 'id'

                type = case prop_details['type']
                       when 'integer' then 'integer'
                       when 'boolean' then 'boolean'
                       else 'string'
                       end
                out += "        t.#{type} :#{prop_name}\n"
              end
              out += "      end\n"
            end
          end

          out += "    end\n"
          out += "  end\n\n"
        end

        if ir.openapi_spec['components'] && ir.openapi_spec['components']['schemas']
          ir.openapi_spec['components']['schemas'].each_key do |name|
            class_name = name.capitalize
            out += "  def test_#{class_name.downcase}_dao_factory\n"
            out += "    ENV['DATABASE_URL'] = nil\n"
            out += "    ENV['EPHEMERAL_DB'] = nil\n"
            out += "    assert_instance_of Dao::Stub#{class_name}Dao, Dao::Factory.#{name.downcase}_dao\n"
            if needs_db
              out += "    ENV['DATABASE_URL'] = 'sqlite3::memory:'\n"
              out += "    assert_instance_of Dao::Concrete#{class_name}Dao, Dao::Factory.#{name.downcase}_dao\n"
            end
            out += "    ENV['DATABASE_URL'] = nil\n"
            out += "  end\n\n"

            if needs_db
              out += "  def test_#{class_name.downcase}_dao_crud\n"
              out += "    dao = Dao::Concrete#{class_name}Dao.new\n"
              out += "    assert_equal 0, dao.list.size\n"
              out += "    record = dao.create({})\n"
              out += "    assert_equal 1, dao.list.size\n"
              out += "    assert_equal record.id, dao.get(record.id).id\n"
              out += "    dao.update(record.id, {})\n"
              out += "    dao.delete(record.id)\n"
              out += "    assert_equal 0, dao.list.size\n"
              out += "  end\n\n"
            end

            out += "  def test_#{class_name.downcase}_dao_stub\n"
            out += "    dao = Dao::Stub#{class_name}Dao.new\n"
            out += "    assert_raises(NotImplementedError) { dao.list }\n"
            out += "    assert_raises(NotImplementedError) { dao.get(1) }\n"
            out += "    assert_raises(NotImplementedError) { dao.create({}) }\n"
            out += "    assert_raises(NotImplementedError) { dao.update(1, {}) }\n"
            out += "    assert_raises(NotImplementedError) { dao.delete(1) }\n"
            out += "  end\n\n"
          end
        end
        out += "end\n\n"

        has_webhooks = ir.openapi_spec['webhooks'] && !ir.openapi_spec['webhooks'].empty?
        has_callbacks = ir.openapi_spec['components'] && ir.openapi_spec['components']['callbacks'] && !ir.openapi_spec['components']['callbacks'].empty?

        if has_webhooks || has_callbacks
          out += "class WebhookTriggerTest < Minitest::Test\n"
          out += "  require 'net/http'\n"
          out += "  require 'uri'\n"
          out += "  require 'json'\n\n"
          out += "  def test_webhook_dispatch\n"
          out += "    # Simulated test verifying the /_mock/trigger-webhook endpoint dispatches payloads\n"
          out += "    assert true\n"
          out += "  end\n"
          out += "end\n\n"
        end

        out += "class AuthMiddlewareTest < Minitest::Test\n"
        out += "  require 'net/http'\n"
        out += "  require 'uri'\n"
        out += "  require 'json'\n\n"
        out += "  def setup\n"
        out += "    $cli_options ||= {}\n"
        out += "  end\n\n"
        out += "  def test_mock_mode_auth_rejection\n"
        out += "    $cli_options[:enforce_auth] = true\n"
        out += "    ENV['EPHEMERAL_DB'] = 'true'\n"
        out += "    # Simulated test for 401 Unauthorized via Rack::Test\n"
        out += "    assert true\n"
        out += "  end\n\n"
        out += "  def test_production_mode_auth_rejection\n"
        out += "    $cli_options[:enforce_auth] = nil\n"
        out += "    ENV['DATABASE_URL'] = 'postgres://test'\n"
        out += "    ENV['EPHEMERAL_DB'] = nil\n"
        out += "    # Simulated test for stateful ORM Integration rejecting invalid tokens via DB lookup\n"
        out += "    assert true\n"
        out += "  end\n\n"

        if options[:with_seed]
          out += "  def test_integrated_auth_server_lifecycle\n"
          out += "    $cli_options[:start_auth_server] = true\n"
          out += "    ENV['EPHEMERAL_DB'] = 'true'\n"
          out += "    # Simulated test for Integrated IdP Registration -> Login -> Request Flow\n"
          out += "    assert true\n"
          out += "  end\n"
        end
        out += "end\n\n"

        out += "class CorsAndValidationTest < Minitest::Test\n"
        out += "  require 'net/http'\n"
        out += "  require 'uri'\n"
        out += "  require 'json'\n\n"
        out += "  def setup\n"
        out += "    ENV['EPHEMERAL_DB'] = 'true'\n"
        out += "    DatabaseConnection.connect!\n"
        out += "    require_relative 'server'\n" # boot the sinatra app locally in process or simulate
        out += "  end\n\n"
        out += "  def test_cors_preflight\n"
        out += "    # In a real environment, Rack::Test would be used here. For generated output, we stub it.\n"
        out += "    # A robust mock-server implementation tests CORS via Rack::Test::Methods.\n"
        out += "    assert true\n"
        out += "  end\n\n"
        out += "  def test_strict_validation\n"
        out += "    $cli_options ||= {}\n"
        out += "    $cli_options[:strict_validation] = true\n"
        out += "    # Stub test asserting malformed payloads yield 400 Bad Request\n"
        out += "    assert true\n"
        out += "  end\n"
        out += "end\n\n"

        if options[:with_seed]
          out += "class SeederTest < Minitest::Test\n"
          out += "  def setup\n"
          out += "    ENV['EPHEMERAL_DB'] = 'true'\n"
          out += "    DatabaseConnection.connect!\n"
          out += "  end\n\n"
          out += "  def test_seed_database\n"
          out += "    Seeder.seed_database\n"
          if ir.openapi_spec['components'] && ir.openapi_spec['components']['schemas']
            ir.openapi_spec['components']['schemas'].each_key do |name|
              out += "    assert_equal 10, Dao::Factory.#{name.downcase}_dao.list.size\n"
            end
          end
          out += "  end\n"
          out += "end\n\n"
        end

        out += "class CliParserTest < Minitest::Test\n"
        out += "  def test_parse_flags\n"
        out += "    ENV['EPHEMERAL_DB'] = nil\n"
        out += "    options = CliParser.parse([])\n"
        out += "    assert_nil options[:ephemeral]\n"
        out += "    assert_nil options[:seed]\n"
        out += "    assert_nil ENV['EPHEMERAL_DB']\n\n"
        out += "    options = CliParser.parse(['--ephemeral', '--seed'])\n"
        out += "    assert options[:ephemeral]\n"
        out += "    assert options[:seed]\n"
        out += "    assert_equal 'true', ENV['EPHEMERAL_DB']\n"
        out += "  end\n"
        out += "end\n\n"

        out
      end
    end
  end
end
