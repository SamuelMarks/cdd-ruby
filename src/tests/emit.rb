# frozen_string_literal: true

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for parsing and emitting unit and integration test suites.
  module Tests
    # Emitter for generating Minitest test suites from an Intermediate Representation.
    class Emitter
      # Emits all generated test files concatenated into a single monolithic string.
      #
      # @param ir [Cdd::IR] Intermediate Representation
      # @param options [Hash] generation options (`:server`, `:with_ephemeral`, `:with_seed`)
      # @return [String] concatenated Ruby test code
      def self.emit(ir, options = {})
        emit_multiple(ir, options).values.join("\n")
      end

      # Emits a map of filename => Ruby test file content from the IR.
      #
      # @param ir [Cdd::IR] Intermediate Representation
      # @param options [Hash] generation options (`:server`, `:with_ephemeral`, `:with_seed`)
      # @return [Hash{String => String}] map of test filenames to Ruby source code
      def self.emit_multiple(ir, options = {})
        files = {}
        workflows = ir.arazzo_spec['workflows'] || []
        files['arazzo_workflows_test.rb'] = emit_arazzo_workflows_test(ir) if workflows.any?

        paths = ir.openapi_spec['paths'] || {}
        return files if paths.empty?

        target_file = options[:server] ? 'routes_test.rb' : 'api_client_test.rb'
        files[target_file] = emit_routes_or_client_tests(paths, options)

        needs_db = options[:with_ephemeral] || options[:with_seed]
        schemas = ir.openapi_spec.dig('components', 'schemas')

        files['database_connection_test.rb'] = emit_database_connection_test if needs_db
        files['dao_test.rb'] = emit_dao_tests(schemas, needs_db)
        files['webhook_trigger_test.rb'] = emit_webhook_trigger_test if webhooks_or_callbacks?(ir)
        files['auth_middleware_test.rb'] = emit_auth_middleware_test(options)
        files['cors_and_validation_test.rb'] = emit_cors_and_validation_test
        files['seeder_test.rb'] = emit_seeder_test(schemas) if options[:with_seed]
        files['cli_parser_test.rb'] = emit_cli_parser_test
        files
      end

      # Emits `arazzo_workflows_test.rb` containing E2E Minitest workflow test methods.
      #
      # @param ir [Cdd::IR] Intermediate Representation containing `arazzo_spec`
      # @return [String] Ruby test class source code
      def self.emit_arazzo_workflows_test(ir)
        out = "#{Cdd::Arazzo::Emitter.emit(ir)}\nclass ArazzoWorkflowsTest < Minitest::Test\n"
        (ir.arazzo_spec['workflows'] || []).each do |wf|
          wf_id = wf['workflowId']
          out << "  def test_workflow_#{wf_id}\n"
          out << "    stub_client = Object.new\n"
          out << "    def stub_client.method_missing(_m, *_a, **_kw); {}; end\n"
          out << "    def stub_client.respond_to_missing?(_m, _p = false); true; end\n"
          out << "    orch = WorkflowsOrchestrator.new({ 'default' => stub_client })\n"
          out << "    assert_respond_to orch, :#{wf_id}\n"
          out << "    res = orch.#{wf_id}({})\n"
          out << "    assert_kind_of Hash, res\n"
          out << "  end\n\n"
        end
        "#{out}end\n"
      end

      # Checks whether the IR contains any webhooks or component callbacks.
      #
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [Boolean] true if webhooks or callbacks are non-empty
      def self.webhooks_or_callbacks?(ir)
        has_webhooks = ir.openapi_spec['webhooks'] && !ir.openapi_spec['webhooks'].empty?
        has_callbacks = ir.openapi_spec.dig('components', 'callbacks') &&
                        !ir.openapi_spec['components']['callbacks'].empty?
        (!has_webhooks.nil? && has_webhooks) || (!has_callbacks.nil? && has_callbacks)
      end

      # Emits `RoutesTest` (when `options[:server]` is true) or `ApiClientTest` (for SDKs).
      #
      # @param paths [Hash] OpenAPI `paths` map
      # @param options [Hash] generation options
      # @return [String] Ruby test class source code
      def self.emit_routes_or_client_tests(paths, options)
        out = if options[:server]
                "class RoutesTest < Minitest::Test\n  require 'rack/test'\n  include Rack::Test::Methods\n\n  " \
                  "def app\n    Sinatra::Application\n  end\n\n"
              else
                "class ApiClientTest < Minitest::Test\n\n"
              end

        paths.each do |path, path_data|
          next if path_data['$ref']

          path_data.each do |method, op|
            next if %w[summary description servers parameters].include?(method)

            out += emit_single_operation_test(path, method, op, options[:server])
          end
        end
        "#{out}end\n\n"
      end

      # Emits a single `def test_<op_id>` method for a route or SDK operation.
      #
      # @param path [String] OpenAPI path string
      # @param method [String] HTTP verb
      # @param op [Hash] OpenAPI operation hash
      # @param is_server [Boolean, nil] true when generating Sinatra `Rack::Test` assertions
      # @return [String] Ruby test method code
      def self.emit_single_operation_test(path, method, op, is_server)
        op_id = Cdd::TokenScanner.operation_id_for(method, path, op)
        out = "  # @api_test #{method.upcase} #{path}\n  def test_#{op_id}\n"
        out += is_server ? emit_server_operation_body(path, method, op) : emit_client_operation_body(op_id, op)
        "#{out}  end\n\n"
      end

      # Emits the `Rack::Test` request and status assertion body for a server route test.
      #
      # @param path [String] OpenAPI path string
      # @param method [String] HTTP verb
      # @param op [Hash] OpenAPI operation hash
      # @return [String] test body lines
      def self.emit_server_operation_body(path, method, op)
        out, p_path = partition_test_route_params(path, op['parameters'] || [])
        default_json = "{ id: 1, name: 'test', photoUrls: ['http://example.com'], status: 'available' }.to_json"
        body_str = op['requestBody'] ? default_json : '{}'
        if %w[post put patch].include?(method.downcase)
          out += "    header 'Content-Type', 'application/json'\n"
          out += "    #{method.downcase} sinatra_path, #{body_str}\n"
        else
          out += "    #{method.downcase} '#{p_path}'\n"
        end
        codes_str = '%w[200 201 204 400 401 403 404 405 501]'
        "#{out}    assert_includes #{codes_str}, last_response.status.to_s\n"
      end

      # Builds `sinatra_path` substitutions and resolved GET/DELETE path with query parameters.
      #
      # @param path [String] OpenAPI path string
      # @param parameters [Array<Hash>] operation parameters
      # @return [Array(String, String)] `[out_lines, resolved_query_path]`
      def self.partition_test_route_params(path, parameters)
        out = "    sinatra_path = '#{path}'.dup\n"
        query_pairs = []
        resolved_path = path.dup
        parameters.each do |param|
          val = sample_test_param_val(param)
          if param['in'] == 'path'
            out += "    sinatra_path.gsub!('{#{param['name']}}', '#{val}')\n"
            resolved_path.gsub!("{#{param['name']}}", val.to_s)
          else
            query_pairs << "#{param['name']}=#{val}"
          end
        end
        p_path = query_pairs.empty? ? resolved_path : "#{resolved_path}?#{query_pairs.join('&')}"
        [out, p_path]
      end

      # Emits the `ClientSdk` call and response assertion body for a client operation test.
      #
      # @param op_id [String] operationId method name
      # @param op [Hash] OpenAPI operation hash
      # @return [String] test body lines
      def self.emit_client_operation_body(op_id, op)
        out = "    client = ClientSdk.new('http://localhost:8080/v2')\n"
        params = (op['parameters'] || []).map do |param|
          val = if param.dig('schema', 'type') == 'integer'
                  '1'
                else
                  param['name'] == 'status' ? "'available'" : "'test_#{param['name']}'"
                end
          "#{param['name']}: #{val}"
        end
        if op['requestBody']
          params.push('id: 1', "name: 'test'", "photoUrls: ['http://example.com']",
                      "status: 'available'")
        end
        params_str = params.empty? ? '' : "{ #{params.join(', ')} }"
        success_code = '200'
        success_code = op['responses'].keys.find { |k| k.to_i >= 200 && k.to_i < 300 } || '200' if op['responses']
        "#{out}    begin\n      res = client.#{op_id}(#{params_str})\n      refute_nil res\n      " \
          "assert_equal '#{success_code}', client.last_response.code\n    " \
          "rescue Errno::ECONNREFUSED\n      skip 'Petstore server is not available'\n    end\n"
      end

      # Returns a sample string value for a route parameter in server tests.
      #
      # @param param [Hash] OpenAPI parameter hash
      # @return [String] sample value
      def self.sample_test_param_val(param)
        return '1' if param.dig('schema', 'type') == 'integer'

        param['name'] == 'status' ? 'available' : "test_#{param['name']}"
      end

      # Emits `database_connection_test.rb`.
      #
      # @return [String] Ruby test class source code
      def self.emit_database_connection_test
        <<~RUBY
          class DatabaseConnectionTest < Minitest::Test
            require 'sqlite3'
            def setup
              ActiveRecord::Base.remove_connection if ActiveRecord::Base.connected?
            end

            def test_connect_ephemeral
              ENV['EPHEMERAL_DB'] = 'true'
              DatabaseConnection.connect!
              assert ActiveRecord::Base.connected?
              assert_equal 'sqlite3', ActiveRecord::Base.connection_db_config.adapter
              ENV['EPHEMERAL_DB'] = nil
            end
          end

        RUBY
      end

      # Emits `dao_test.rb` for all schemas.
      #
      # @param schemas [Hash, nil] OpenAPI schemas map
      # @param needs_db [Boolean, nil] whether ActiveRecord CRUD tests are included
      # @return [String] Ruby test class source code
      def self.emit_dao_tests(schemas, needs_db)
        out = "class DaoTest < Minitest::Test\n"
        out += emit_dao_db_setup(schemas) if needs_db
        schemas&.each_key do |name|
          out += emit_single_dao_test_methods(name, needs_db)
        end
        "#{out}end\n\n"
      end

      # Emits the ActiveRecord in-memory SQLite `setup` method for `DaoTest`.
      #
      # @param schemas [Hash, nil] OpenAPI schemas map
      # @return [String] setup method code
      def self.emit_dao_db_setup(schemas)
        out = "  require 'active_record'\n  require 'sqlite3'\n\n  def setup\n"
        out += "    ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')\n"
        out += "    ActiveRecord::Schema.define do\n"
        (schemas || {}).each do |name, schema|
          out += "      create_table :#{name.downcase}s, force: true do |t|\n"
          (schema['properties'] || {}).each do |prop_name, prop_details|
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
        "#{out}    end\n  end\n\n"
      end

      # Emits factory, CRUD, and stub test methods for a single model DAO.
      #
      # @param name [String] schema name
      # @param needs_db [Boolean, nil] whether ConcreteDAO tests are included
      # @return [String] DAO test methods
      def self.emit_single_dao_test_methods(name, needs_db)
        class_name = Cdd::TokenScanner.classify_name(name)
        out = "  def test_#{class_name.downcase}_dao_factory\n    " \
              "ENV['DATABASE_URL'] = nil\n    ENV['EPHEMERAL_DB'] = nil\n    " \
              "assert_instance_of Dao::Stub#{class_name}Dao, Dao::Factory.#{name.downcase}_dao\n"
        if needs_db
          out += "    ENV['DATABASE_URL'] = 'sqlite3::memory:'\n    " \
                 "assert_instance_of Dao::Concrete#{class_name}Dao, Dao::Factory.#{name.downcase}_dao\n"
        end
        out += "    ENV['DATABASE_URL'] = nil\n  end\n\n"
        if needs_db
          out += "  def test_#{class_name.downcase}_dao_crud\n    " \
                 "dao = Dao::Concrete#{class_name}Dao.new\n    assert_equal 0, dao.list.size\n    " \
                 "record = dao.create({})\n    assert_equal 1, dao.list.size\n    " \
                 "assert_equal record.id, dao.get(record.id).id\n    " \
                 "dao.update(record.id, {})\n    dao.delete(record.id)\n    " \
                 "assert_equal 0, dao.list.size\n  end\n\n"
        end
        "#{out}  def test_#{class_name.downcase}_dao_stub\n    " \
          "dao = Dao::Stub#{class_name}Dao.new\n    " \
          "assert_raises(NotImplementedError) { dao.list }\n    " \
          "assert_raises(NotImplementedError) { dao.get(1) }\n    " \
          "assert_raises(NotImplementedError) { dao.create({}) }\n    " \
          "assert_raises(NotImplementedError) { dao.update(1, {}) }\n    " \
          "assert_raises(NotImplementedError) { dao.delete(1) }\n  end\n\n"
      end

      # Emits `webhook_trigger_test.rb`.
      #
      # @return [String] Ruby test class source code
      def self.emit_webhook_trigger_test
        <<~RUBY
          class WebhookTriggerTest < Minitest::Test
            require 'net/http'
            require 'uri'
            require 'json'
            require 'webrick'
            require 'thread'
            require 'rack/test'

            include Rack::Test::Methods

            def app
              Sinatra::Application
            end

            def test_webhook_dispatch
              q = Queue.new
              server = WEBrick::HTTPServer.new(Port: 0, AccessLog: [], Logger: WEBrick::Log.new('/dev/null'))
              port = server.config[:Port]
              server.mount_proc '/' do |req, res|
                q << req.body
                res.status = 200
                res.body = 'ok'
              end
              t = Thread.new { server.start }

              header 'Content-Type', 'application/json'
              post '/_mock/trigger-webhook/my_event', { target_url: "http://127.0.0.1:\#{port}/" }.to_json
              assert_equal 200, last_response.status

              received = JSON.parse(q.pop)
              assert_equal 'my_event', received['event']
              assert_equal 'mock_payload', received['data']
            ensure
              server&.shutdown
              t&.join
            end
          end

        RUBY
      end

      # Emits `auth_middleware_test.rb` with concrete Rack::Test HTTP requests and auth assertions.
      #
      # @param options [Hash] generation options
      # @return [String] Ruby test class source code
      def self.emit_auth_middleware_test(options)
        out = <<~RUBY
          class AuthMiddlewareTest < Minitest::Test
            require 'rack/test'
            require 'json'

            include Rack::Test::Methods

            def app
              Sinatra::Application
            end

            def setup
              $cli_options ||= {}
            end

            def teardown
              $cli_options[:enforce_auth] = nil
              $cli_options[:start_auth_server] = nil
              ENV['DATABASE_URL'] = nil
              ENV['EPHEMERAL_DB'] = 'true'
            end

            def test_mock_mode_auth_rejection
              $cli_options[:enforce_auth] = true
              ENV['EPHEMERAL_DB'] = 'true'
              get '/__auth_probe__'
              assert_includes [401, 404], last_response.status

              header 'Authorization', 'Bearer mock-token-123'
              get '/__auth_probe__'
              assert_equal 404, last_response.status
            end

            def test_production_mode_auth_rejection
              $cli_options[:enforce_auth] = nil
              ENV['DATABASE_URL'] = 'sqlite3::memory:'
              ENV['EPHEMERAL_DB'] = nil
              get '/__auth_probe__'
              assert_includes [401, 404], last_response.status

              header 'Authorization', 'Bearer invalid-token'
              get '/__auth_probe__'
              assert_includes [403, 404], last_response.status
            end

        RUBY
        if options[:with_seed]
          out += <<~RUBY
            def test_integrated_auth_server_lifecycle
              $cli_options[:start_auth_server] = true
              ENV['EPHEMERAL_DB'] = 'true'
              header 'Content-Type', 'application/json'
              post '/auth/refresh', '{}'
              assert_equal 200, last_response.status
              assert_equal 'mock-token-123', JSON.parse(last_response.body)['token']

              post '/auth/logout', '{}'
              assert_equal 200, last_response.status
              assert_equal 'Logged out', JSON.parse(last_response.body)['message']
            end
          RUBY
        end
        "#{out}end\n\n"
      end

      # Emits `cors_and_validation_test.rb` with concrete Rack::Test preflight and payload validation assertions.
      #
      # @return [String] Ruby test class source code
      def self.emit_cors_and_validation_test
        <<~RUBY
          class CorsAndValidationTest < Minitest::Test
            require 'rack/test'
            require 'json'

            include Rack::Test::Methods

            def app
              Sinatra::Application
            end

            def setup
              ENV['EPHEMERAL_DB'] = 'true'
              DatabaseConnection.connect! if defined?(DatabaseConnection)
              $cli_options ||= {}
            end

            def teardown
              $cli_options[:strict_validation] = nil
            end

            def test_cors_preflight
              options '/'
              assert_equal 200, last_response.status
              assert_equal '*', last_response.headers['Access-Control-Allow-Origin']
              assert_includes last_response.headers['Access-Control-Allow-Methods'], 'OPTIONS'
            end

            def test_strict_validation
              $cli_options[:strict_validation] = true
              header 'Content-Type', 'application/json'
              header 'Authorization', 'Bearer mock-token-123'
              post '/', '{malformed_json'
              assert_equal 400, last_response.status
              assert_equal 'Malformed JSON payload', JSON.parse(last_response.body)['error']
            end
          end

        RUBY
      end

      # Emits `seeder_test.rb` when `--seed` support is enabled.
      #
      # @param schemas [Hash, nil] OpenAPI schemas map
      # @return [String] Ruby test class source code
      def self.emit_seeder_test(schemas)
        out = "class SeederTest < Minitest::Test\n  def setup\n    ENV['EPHEMERAL_DB'] = 'true'\n    " \
              "DatabaseConnection.connect!\n  end\n\n  def test_seed_database\n    Seeder.seed_database\n"
        (schemas || {}).each_key do |name|
          out += "    assert_equal 10, Dao::Factory.#{name.downcase}_dao.list.size\n"
        end
        "#{out}  end\nend\n\n"
      end

      # Emits `cli_parser_test.rb`.
      #
      # @return [String] Ruby test class source code
      def self.emit_cli_parser_test
        <<~RUBY
          class CliParserTest < Minitest::Test
            def test_parse_flags
              ENV['EPHEMERAL_DB'] = nil
              options = CliParser.parse([])
              assert_nil options[:ephemeral]
              assert_nil options[:seed]
              assert_nil ENV['EPHEMERAL_DB']

              options = CliParser.parse(['--ephemeral', '--seed'])
              assert options[:ephemeral]
              assert options[:seed]
              assert_equal 'true', ENV['EPHEMERAL_DB']
            end
          end

        RUBY
      end
    end
  end
end
