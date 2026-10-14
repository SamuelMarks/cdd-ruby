# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative '../scaffolding'
require_relative '../client_sdk_cli/emit'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Server generation and parsing module.
  module ServerGen
    # Emitter for generating a complete Sinatra server, DAOs, models, middlewares, and tests.
    class Emitter
      # Emits a complete Sinatra server application and optional test/mock suites from an OpenAPI spec.
      #
      # @param options [Hash] generation options (`:input`, `:input_dir`, `:output`, `:with_ephemeral`, etc.)
      # @return [String] generated `server.rb` entrypoint source code
      def self.emit_server(options)
        input_file = options[:input] || Dir.glob("#{options[:input_dir]}/*.json").first
        openapi = JSON.parse(File.read(input_file))
        out_dir = options[:output] || Dir.pwd
        FileUtils.mkdir_p(out_dir)

        Cdd::Scaffolding.generate(options, 'server')
        schemas = openapi.dig('components', 'schemas') || openapi['definitions'] || {}
        %w[config middlewares models daos routes].each { |dir| FileUtils.mkdir_p(File.join(out_dir, dir)) }
        needs_db = options[:with_ephemeral] || options[:with_seed]

        emit_cli_parser_file(out_dir)
        emit_database_file(out_dir, schemas) if needs_db
        emit_model_files(out_dir, schemas, needs_db)
        emit_dao_files(out_dir, schemas, needs_db)
        emit_seeder_file(out_dir, schemas) if options[:with_seed]
        emit_middleware_files(out_dir, openapi, needs_db)
        emit_auth_routes_file(out_dir, needs_db)
        emit_webhook_routes_file(out_dir, openapi)
        emit_domain_routes_files(out_dir, openapi, schemas)
        emit_mcp_routes_file(out_dir, openapi)

        server_code = emit_server_entrypoint(out_dir, openapi)
        emit_server_tests_and_mocks(options, openapi) if options[:tests]
        server_code
      end

      # Converts a schema name into a valid PascalCase Ruby class name.
      #
      # @param name [String] raw schema name
      # @return [String] PascalCase class name
      def self.classify_name(name)
        name.to_s.sub(/\A[a-z]/, &:upcase)
      end

      # Emits `config/cli_parser.rb`.
      #
      # @param out_dir [String] server output directory
      # @return [void]
      def self.emit_cli_parser_file(out_dir)
        cli_code = <<~RUBY
          # frozen_string_literal: true

          # Parses CLI flags and sets the environment appropriately.
          class CliParser
            # @param args [Array<String>] CLI arguments
            # @return [Hash] the parsed options
            def self.parse(args)
              options = {}
              if args.include?('--ephemeral')
                options[:ephemeral] = true
                ENV['EPHEMERAL_DB'] = 'true'
                args.delete('--ephemeral')
              end
              if args.include?('--seed')
                options[:seed] = true
                args.delete('--seed')
              end
              if args.include?('--strict-validation')
                options[:strict_validation] = true
                args.delete('--strict-validation')
              end
              if args.include?('--enforce-auth')
                options[:enforce_auth] = true
                args.delete('--enforce-auth')
              end
              if args.include?('--start-auth-server')
                options[:start_auth_server] = true
                args.delete('--start-auth-server')
              end
              options
            end
          end
        RUBY
        File.write(File.join(out_dir, 'config', 'cli_parser.rb'), cli_code)
      end

      # Emits `config/database.rb` when database support is enabled.
      #
      # @param out_dir [String] server output directory
      # @param schemas [Hash] OpenAPI schemas map
      # @return [void]
      def self.emit_database_file(out_dir, schemas)
        db_code = <<~RUBY
          # frozen_string_literal: true

          require 'active_record'

          # Initializes the connection based on environment variables and CLI flags.
          class DatabaseConnection
            # @return [void]
            def self.connect!
              if ENV['EPHEMERAL_DB'] == 'true' || ARGV.include?('--ephemeral')
                db_file = File.join(Dir.pwd, 'ephemeral.sqlite3')
                ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: db_file)
                migrate!
              elsif ENV['DATABASE_URL']
                ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])
              end
            end

            # Executes DB schema migrations programmatically.
            # @return [void]
            def self.migrate!
              ActiveRecord::Schema.define do
        RUBY
        schemas.each do |name, schema|
          db_code += "        create_table :#{name.downcase}s, force: true do |t|\n"
          (schema['properties'] || {}).each do |prop_name, prop_details|
            next if prop_name == 'id'

            type = case prop_details['type']
                   when 'integer' then 'integer'
                   when 'boolean' then 'boolean'
                   else 'string'
                   end
            db_code += "          t.#{type} :#{prop_name}\n"
          end
          db_code += "        end\n"
        end
        db_code += "      end\n    end\n  end\n"
        File.write(File.join(out_dir, 'config', 'database.rb'), db_code)
      end

      # Emits `models/<name>.rb` files for all schemas.
      #
      # @param out_dir [String] server output directory
      # @param schemas [Hash] OpenAPI schemas map
      # @param needs_db [Boolean, nil] whether ActiveRecord inheritance is enabled
      # @return [void]
      def self.emit_model_files(out_dir, schemas, needs_db)
        schemas.each do |name, schema|
          class_name = classify_name(name)
          model_code = "# frozen_string_literal: true\n\n"
          model_code += "require 'active_record'\n\n" if needs_db
          model_code += "# #{class_name} model\n"
          model_code += if needs_db
                          "class #{class_name} < ActiveRecord::Base\n  self.table_name = '#{name.downcase}s'\n"
                        else
                          "class #{class_name}\n"
                        end
          schema['properties']&.each do |prop_name, prop_details|
            model_code += "  # property: #{prop_name} (#{prop_details['type']})\n"
          end
          if schema['discriminator']
            model_code += "  # Discriminator: #{schema['discriminator']['propertyName']}\n"
            if schema['discriminator']['mapping']
              model_code += "  # Mapping: #{schema['discriminator']['mapping'].to_json}\n"
            end
          end
          model_code += "  # XML Mapping: #{schema['xml'].to_json}\n" if schema['xml']
          model_code += "end\n"
          File.write(File.join(out_dir, 'models', "#{name.downcase}.rb"), model_code)
        end
      end

      # Emits `daos/<name>_dao.rb` and `daos/factory.rb`.
      #
      # @param out_dir [String] server output directory
      # @param schemas [Hash] OpenAPI schemas map
      # @param needs_db [Boolean, nil] whether ActiveRecord ConcreteDAOs are generated
      # @return [void]
      def self.emit_dao_files(out_dir, schemas, needs_db)
        schemas.each_key do |name|
          class_name = classify_name(name)
          File.write(File.join(out_dir, 'daos', "#{name.downcase}_dao.rb"), build_single_dao_code(class_name, needs_db))
        end
        File.write(File.join(out_dir, 'daos', 'factory.rb'), build_dao_factory_code(schemas, needs_db))
      end

      # Builds the Ruby source code for a single model's Abstract, Stub, and Concrete DAO classes.
      #
      # @param class_name [String] PascalCase model class name
      # @param needs_db [Boolean, nil] whether ConcreteDAO is included
      # @return [String] DAO file source code
      def self.build_single_dao_code(class_name, needs_db)
        dao_code = "# frozen_string_literal: true\n\nmodule Dao\n"
        [['Abstract', '', ''], ['Stub', " < Abstract#{class_name}Dao", ' (Stub)']].each do |prefix, parent, label|
          dao_code += <<~RUBY
            # #{prefix} DAO for #{class_name}
            class #{prefix}#{class_name}Dao#{parent}
              # Fetch all records#{label}
              def list; raise NotImplementedError; end
              # Get record by ID#{label}
              # @param id [Integer, String] the record ID
              def get(id); raise NotImplementedError; end
              # Create a record#{label}
              # @param params [Hash] attributes
              def create(params); raise NotImplementedError; end
              # Update a record#{label}
              # @param id [Integer, String] the record ID
              # @param params [Hash] attributes
              def update(id, params); raise NotImplementedError; end
              # Delete a record#{label}
              # @param id [Integer, String] the record ID
              def delete(id); raise NotImplementedError; end
            end

          RUBY
        end
        if needs_db
          dao_code += <<~RUBY
            # Concrete DAO for #{class_name} backed by ActiveRecord
            class Concrete#{class_name}Dao < Abstract#{class_name}Dao
              # Fetch all records (ActiveRecord)
              def list; ::#{class_name}.all; end
              # Get record by ID (ActiveRecord)
              def get(id); ::#{class_name}.find(id); end
              # Create a record (ActiveRecord)
              def create(params); ::#{class_name}.create!(params); end
              # Update a record (ActiveRecord)
              def update(id, params); record = ::#{class_name}.find(id); record.update!(params); record; end
              # Delete a record (ActiveRecord)
              def delete(id); ::#{class_name}.find(id).destroy; end
            end
          RUBY
        end
        "#{dao_code}end\n"
      end

      # Builds the `Dao::Factory` source code.
      #
      # @param schemas [Hash] OpenAPI schemas map
      # @param needs_db [Boolean, nil] whether ConcreteDAO selection is enabled
      # @return [String] factory source code
      def self.build_dao_factory_code(schemas, needs_db)
        factory_code = "# frozen_string_literal: true\n\nmodule Dao\n"
        factory_code += "  # Factory to get DAO implementations based on environment\n  class Factory\n"
        schemas.each_key do |name|
          class_name = classify_name(name)
          factory_code += "    # Get #{class_name} DAO\n    # @return [Abstract#{class_name}Dao] the configured DAO\n"
          factory_code += "    def self.#{name.downcase}_dao\n"
          if needs_db
            factory_code += "      if ENV['DATABASE_URL'] || ENV['EPHEMERAL_DB'] == 'true' || " \
                            "ARGV.include?('--ephemeral')\n"
            factory_code += "        Concrete#{class_name}Dao.new\n      else\n        " \
                            "Stub#{class_name}Dao.new\n      end\n"
          else
            factory_code += "      Stub#{class_name}Dao.new\n"
          end
          factory_code += "    end\n\n"
        end
        "#{factory_code}  end\nend\n"
      end

      # Emits `config/seeder.rb` when `--seed` support is enabled.
      #
      # @param out_dir [String] server output directory
      # @param schemas [Hash] OpenAPI schemas map
      # @return [void]
      def self.emit_seeder_file(out_dir, schemas)
        seeder_code = <<~RUBY
          # frozen_string_literal: true

          require 'faker'

          # The Seeder module generates realistic fake data graphs.
          # It manages referential integrity by utilizing an in-memory entity pool.
          module Seeder
            Faker::Config.locale = 'en'

            # Entity pool for caching generated records' IDs to satisfy foreign keys.
            @pool = {}

        RUBY
        schemas.each do |name, schema|
          seeder_code += "  # Factory for #{name}\n  # @return [Hash] the attributes for the new record\n"
          seeder_code += "  def self.generate_#{name.downcase}\n    {\n"
          (schema['properties'] || {}).each do |prop_name, prop_details|
            next if prop_name == 'id'

            seeder_code += "      #{prop_name}: #{faker_expression_for(prop_name, prop_details)},\n"
          end
          seeder_code += "    }\n  end\n\n"
        end
        seeder_code += "  # Seeds the database with fake data.\n  " \
                       "# @param dao_factory [Class] the DAO factory to use for creation\n  # @return [void]\n"
        seeder_code += "  def self.seed_database(dao_factory = Dao::Factory)\n"
        sorted_names = schemas.keys.sort_by do |n|
          (schemas[n]['properties'] || {}).keys.count { |p| p.match(/[_I]d$/) }
        end
        sorted_names.each do |name|
          seeder_code += "    @pool[:#{name.downcase}] = []\n    10.times do\n"
          seeder_code += "      record = dao_factory.#{name.downcase}_dao.create(generate_#{name.downcase})\n"
          seeder_code += "      @pool[:#{name.downcase}] << record.id if record.respond_to?(:id)\n    end\n"
        end
        File.write(File.join(out_dir, 'config', 'seeder.rb'), "#{seeder_code}  end\nend\n")
      end

      # Returns a Faker or random Ruby expression for a schema property in `Seeder`.
      #
      # @param prop_name [String] property name
      # @param prop_details [Hash] property schema hash
      # @return [String] Ruby expression string
      def self.faker_expression_for(prop_name, prop_details)
        is_fk = prop_name.match(/^(.*)[_I]d$/)
        if is_fk
          parent_model = is_fk[1].downcase
          "(@pool[:#{parent_model}] && !@pool[:#{parent_model}].empty?) ? " \
            "@pool[:#{parent_model}].sample : rand(1..1000)"
        elsif prop_details['type'] == 'integer'
          'rand(1..1000)'
        elsif prop_details['type'] == 'boolean'
          '[true, false].sample'
        elsif prop_name.downcase.include?('email')
          'Faker::Internet.email'
        elsif prop_name.downcase.include?('name')
          'Faker::Name.name'
        elsif prop_name.downcase.include?('phone')
          'Faker::PhoneNumber.phone_number'
        else
          'Faker::Lorem.word'
        end
      end

      # Emits `middlewares/cors.rb`, `middlewares/validation.rb`, and `middlewares/auth.rb`.
      #
      # @param out_dir [String] server output directory
      # @param openapi [Hash] parsed OpenAPI specification
      # @param needs_db [Boolean, nil] whether DB-backed token lookup is included
      # @return [void]
      def self.emit_middleware_files(out_dir, openapi, needs_db)
        cors_code = <<~RUBY
          # frozen_string_literal: true

          require 'sinatra'

          # Permissive CORS Middleware
          before do
            headers 'Access-Control-Allow-Origin' => '*',
                    'Access-Control-Allow-Methods' => 'GET, POST, PUT, DELETE, PATCH, OPTIONS',
                    'Access-Control-Allow-Headers' => 'Authorization, Content-Type, Accept'
          end

          options '*' do
            response.headers['Allow'] = 'GET, POST, PUT, DELETE, PATCH, OPTIONS'
            response.headers['Access-Control-Allow-Headers'] = 'Authorization, Content-Type, Accept'
            response.headers['Access-Control-Allow-Origin'] = '*'
            200
          end
        RUBY
        File.write(File.join(out_dir, 'middlewares', 'cors.rb'), cors_code)

        val_code = <<~RUBY
          # frozen_string_literal: true

          require 'sinatra'
          require 'json'

          # Strict Validation Middleware
          before do
            if $cli_options[:strict_validation]
              request.body.rewind
              body_str = request.body.read
              unless body_str.empty?
                begin
                  JSON.parse(body_str)
                rescue JSON::ParserError
                  halt 400, { error: 'Malformed JSON payload' }.to_json
                end
              end
              request.body.rewind
            end
          end
        RUBY
        File.write(File.join(out_dir, 'middlewares', 'validation.rb'), val_code)
        File.write(File.join(out_dir, 'middlewares', 'auth.rb'), build_auth_middleware_code(openapi, needs_db))
      end

      # Builds the `middlewares/auth.rb` source code.
      #
      # @param openapi [Hash] parsed OpenAPI specification
      # @param needs_db [Boolean, nil] whether DB-backed token verification is included
      # @return [String] auth middleware source code
      def self.build_auth_middleware_code(openapi, needs_db)
        auth_code = "# frozen_string_literal: true\n\nrequire 'sinatra'\nrequire 'json'\n\n"
        return auth_code unless openapi.dig('components', 'securitySchemes')

        auth_code += <<~RUBY
          # Security Middleware
          before do
            pass if request.path_info == '/mcp/sse' || request.path_info == '/mcp/message'
            pass if request.path_info.start_with?('/auth/')
            if $cli_options[:enforce_auth] || (ENV['EPHEMERAL_DB'] == 'true')
              auth_header = request.env['HTTP_AUTHORIZATION'] || request.env['HTTP_API_KEY']
              halt 401, { error: 'Unauthorized' }.to_json unless auth_header && auth_header.include?('mock-token')
        RUBY
        if needs_db
          auth_code += <<~RUBY
            elsif ENV['DATABASE_URL'] && ENV['EPHEMERAL_DB'] != 'true'
              auth_header = request.env['HTTP_AUTHORIZATION'] || request.env['HTTP_API_KEY']
              halt 401, { error: 'Unauthorized' }.to_json unless auth_header
              token = auth_header.gsub('Bearer ', '')
              begin
                user = Dao::Factory.user_dao.list.find { |u| u.respond_to?(:password) && u.password == token }
                halt 403, { error: 'Forbidden: Invalid Token' }.to_json unless user
              rescue StandardError
              end
          RUBY
        end
        "#{auth_code}  end\nend\n"
      end

      # Emits `routes/auth_routes.rb`.
      #
      # @param out_dir [String] server output directory
      # @param needs_db [Boolean, nil] whether DB-backed user creation/login is enabled
      # @return [void]
      def self.emit_auth_routes_file(out_dir, needs_db)
        reg_line = if needs_db
                     <<~RUBY.chomp
                       user = Dao::Factory.user_dao.create(req)
                       { message: 'Registered Successfully', id: user.respond_to?(:id) ? user.id : 'generated' }.to_json
                     RUBY
                   else
                     "      { message: 'Registered Successfully (Stub)', id: 'stub' }.to_json"
                   end
        login_line = if needs_db
                       <<~RUBY.chomp
                         user = Dao::Factory.user_dao.list.find { |u| u.respond_to?(:username) && u.username == req['username'] }
                         if user && user.respond_to?(:password) && user.password == req['password']
                           { token: user.password }.to_json
                       RUBY
                     else
                       <<~RUBY.chomp
                         if req['username'] == 'admin' && req['password'] == 'password'
                           { token: 'mock-token-123' }.to_json
                       RUBY
                     end
        auth_routes = <<~RUBY
          # frozen_string_literal: true

          require 'sinatra'
          require 'json'

          # Integrated Identity Provider (IdP) module
          if $cli_options[:start_auth_server]
            post '/auth/register' do
              content_type :json
              begin
                req = JSON.parse(request.body.read)
          #{reg_line}
              rescue StandardError => e
                halt 400, { error: e.message }.to_json
              end
            end

            post '/auth/login' do
              content_type :json
              begin
                req = JSON.parse(request.body.read)
          #{login_line}
                else
                  halt 401, { error: 'Invalid Credentials' }.to_json
                end
              rescue StandardError => e
                halt 400, { error: e.message }.to_json
              end
            end

            post '/auth/refresh' do
              content_type :json
              { token: 'mock-token-123' }.to_json
            end

            post '/auth/logout' do
              content_type :json
              { message: 'Logged out' }.to_json
            end
          end
        RUBY
        File.write(File.join(out_dir, 'routes', 'auth_routes.rb'), auth_routes)
      end

      # Emits `routes/webhook_routes.rb`.
      #
      # @param out_dir [String] server output directory
      # @param openapi [Hash] parsed OpenAPI specification
      # @return [void]
      def self.emit_webhook_routes_file(out_dir, openapi)
        has_webhooks = openapi['webhooks'] && !openapi['webhooks'].empty?
        has_callbacks = openapi.dig('components', 'callbacks') && !openapi['components']['callbacks'].empty?
        wh_code = "# frozen_string_literal: true\n\nrequire 'sinatra'\nrequire 'json'\n" \
                  "require 'net/http'\nrequire 'uri'\n\n"
        if has_webhooks || has_callbacks
          wh_code += <<~RUBY
            # Administrative Webhook Trigger API
            post '/_mock/trigger-webhook/:name' do
              content_type :json
              begin
                req = JSON.parse(request.body.read)
                target_url = req['target_url'] || params[:target_url]
                halt 400, { error: 'Missing target_url' }.to_json unless target_url
                uri = URI(target_url)
                payload = { event: params[:name], data: 'mock_payload' }.to_json
                http_req = Net::HTTP::Post.new(uri)
                http_req['Content-Type'] = 'application/json'
                http_req.body = payload
                Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
                  http.request(http_req)
                end
                { message: 'Webhook Dispatched' }.to_json
              rescue StandardError => e
                halt 500, { error: e.message }.to_json
              end
            end
          RUBY
        end
        File.write(File.join(out_dir, 'routes', 'webhook_routes.rb'), wh_code)
      end

      # Emits domain route files (`routes/<model>_routes.rb`) for all OpenAPI paths.
      #
      # @param out_dir [String] server output directory
      # @param openapi [Hash] parsed OpenAPI specification
      # @param schemas [Hash] OpenAPI schemas map
      # @return [void]
      def self.emit_domain_routes_files(out_dir, openapi, schemas)
        domain_routes_map = {}
        openapi['paths']&.each do |path, methods|
          sinatra_path = path.gsub(/\{([^}]+)\}/, ':\1')
          model_name = resolve_route_model_name(path, schemas)
          file_key = model_name ? model_name.downcase : 'general'
          domain_routes_map[file_key] ||= "# frozen_string_literal: true\n\nrequire 'sinatra'\nrequire 'json'\n\n"
          methods.each do |method, details|
            domain_routes_map[file_key] += build_domain_route_block(sinatra_path, method, details, model_name)
          end
        end
        domain_routes_map.each do |key, code|
          File.write(File.join(out_dir, 'routes', "#{key}_routes.rb"), code)
        end
      end

      # Matches a route path segment to a known schema model name.
      #
      # @param path [String] OpenAPI route path
      # @param schemas [Hash] OpenAPI schemas map
      # @return [String, nil] matched model name or nil
      def self.resolve_route_model_name(path, schemas)
        possible_resources = path.split('/').reject do |p|
          p.empty? || p.include?('{') || %w[api v1 v2 v3 v4].include?(p.downcase)
        end
        model_hint = possible_resources.first.to_s
        singular = model_hint.end_with?('s') ? model_hint[0...-1] : model_hint
        schemas.keys.find { |k| k.downcase == singular.downcase || k.downcase == model_hint.downcase }
      end

      # Builds a single Sinatra route handler block and its operation docstrings.
      #
      # @param sinatra_path [String] Sinatra route pattern
      # @param method [String] HTTP verb
      # @param details [Hash] OpenAPI operation details
      # @param model_name [String, nil] associated model name if any
      # @return [String] Sinatra route block code
      def self.build_domain_route_block(sinatra_path, method, details, model_name)
        r_code = "# Operation: #{details['operationId'] || method.upcase}\n"
        r_code += "# Summary: #{details['summary']}\n" if details['summary']
        r_code += "# Description: #{details['description']}\n" if details['description']
        r_code += "# Deprecated: true\n" if details['deprecated']

        path_param = nil
        details['parameters']&.each do |param|
          req = param['required'] ? 'required' : 'optional'
          r_code += "# Param [#{param['in']}]: #{param['name']} (#{req})\n"
          path_param ||= param['name'] if param['in'] == 'path'
        end
        if details['requestBody']
          r_code += "# Request Body: expected\n"
          details['requestBody']['content']&.each_key { |mt| r_code += "# Content-Type: #{mt}\n" }
        end

        r_code += "#{method.downcase} '#{sinatra_path}' do\n  content_type :json\n"
        r_code += if model_name
                    build_dao_backed_route_body(method.downcase, model_name, path_param)
                  else
                    "  halt 501, { message: 'Not implemented' }.to_json\n"
                  end
        "#{r_code}end\n\n"
      end

      # Builds the DAO-backed `begin ... rescue ... end` block inside a domain route handler.
      #
      # @param verb [String] lowercase HTTP method
      # @param model_name [String] schema model name
      # @param path_param [String, nil] primary path parameter name
      # @return [String] DAO dispatch code
      def self.build_dao_backed_route_body(verb, model_name, path_param)
        out = "  begin\n    dao = Dao::Factory.#{model_name.downcase}_dao\n"
        out += case verb
               when 'get'
                 if path_param
                   "    record = dao.get(params[:#{path_param}])\n    " \
                     "halt 404, { error: 'Not found' }.to_json unless record\n    record.to_json\n"
                 else
                   "    dao.list.to_json\n"
                 end
               when 'post'
                 "    req_body = JSON.parse(request.body.read) rescue {}\n    dao.create(req_body).to_json\n"
               when 'put', 'patch'
                 if path_param
                   "    req_body = JSON.parse(request.body.read) rescue {}\n    " \
                     "dao.update(params[:#{path_param}], req_body).to_json\n"
                 else
                   "    { message: 'Not implemented (missing ID)' }.to_json\n"
                 end
               when 'delete'
                 if path_param
                   "    dao.delete(params[:#{path_param}])\n    status 204\n    ''\n"
                 else
                   "    { message: 'Not implemented (missing ID)' }.to_json\n"
                 end
               else
                 "    { message: 'Not implemented' }.to_json\n"
               end
        "#{out}  rescue NotImplementedError\n    halt 501, { message: 'Not implemented' }.to_json\n  " \
          "rescue StandardError => e\n    halt 400, { error: e.message }.to_json\n  end\n"
      end

      # Emits `routes/mcp_routes.rb` using `ClientSdkCli::Emitter.build_mcp_tools`.
      #
      # @param out_dir [String] server output directory
      # @param openapi [Hash] parsed OpenAPI specification
      # @return [void]
      def self.emit_mcp_routes_file(out_dir, openapi)
        tools_json = Cdd::ClientSdkCli::Emitter.build_mcp_tools(openapi).to_json
        mcp_code = <<~RUBY
          # frozen_string_literal: true

          require 'sinatra'
          require 'json'

          set :mcp_connections, []
          get '/mcp/sse' do
            content_type 'text/event-stream'
            stream(:keep_open) do |out|
              settings.mcp_connections << out
              out << "event: endpoint\\ndata: /mcp/message\\n\\n"
              out.callback { settings.mcp_connections.delete(out) }
            end
          end

          post '/mcp/message' do
            begin
              req = JSON.parse(request.body.read)
            rescue JSON::ParserError
              status 202
              resp = { jsonrpc: '2.0', error: { code: -32700, message: 'Parse error' } }
              settings.mcp_connections.each { |out| out << "event: message\\ndata: \#{resp.to_json}\\n\\n" }
              return
            end
            if req['id'].nil?
              return
            end
            resp = { jsonrpc: '2.0', id: req['id'], result: { _meta: {} } }
            if req['method'] == 'initialize'
              resp[:result] = { capabilities: { tools: { listChanged: true }, logging: {}, experimental: {}, roots: { listChanged: true }, sampling: {} }, serverInfo: { name: 'mcp-server', version: '1.0.0' }, protocolVersion: '2024-11-05', instructions: '' }
            elsif req['method'] == 'ping' || req['method'] == 'logging/setLevel'
              resp[:result] = {}
            elsif req['method'] == 'roots/list'
              resp[:result] = { roots: [] }
            elsif req['method'] == 'resources/templates/list'
              resp[:result] = { resourceTemplates: [] }
            elsif req['method'] == 'sampling/createMessage'
              resp[:result] = { role: 'assistant', model: 'stub-model', content: { type: 'text', text: 'sampled' } }
            elsif req['method'] == 'completion/complete'
              resp[:result] = { completion: { values: [], total: 0, hasMore: false } }
            elsif req['method'] == 'tools/list'
              resp[:result] = { tools: #{tools_json} }
            elsif req['method'] == 'tools/call'
              resp[:result] = { content: [{ type: 'text', text: 'Calling tool ' + req.dig('params', 'name').to_s }] }
            else
              resp = { jsonrpc: '2.0', id: req['id'], error: { code: -32601, message: 'Method not found' } }
            end
            settings.mcp_connections.each { |out| out << "event: message\\ndata: \#{resp.to_json}\\n\\n" }
            status 202
          end
        RUBY
        File.write(File.join(out_dir, 'routes', 'mcp_routes.rb'), mcp_code)
      end

      # Emits `server.rb` and returns its content.
      #
      # @param out_dir [String] server output directory
      # @param openapi [Hash] parsed OpenAPI specification
      # @return [String] generated `server.rb` content
      def self.emit_server_entrypoint(out_dir, openapi)
        server_code = "# frozen_string_literal: true\n\n$cli_options ||= {}\n"
        server_code += "require_relative 'config/cli_parser'\n"
        server_code += "$cli_options = CliParser.parse(ARGV) if ARGV.any?\n\n"
        server_code += "require 'sinatra'\nrequire 'json'\n\nset :server, :puma\n\n"
        if openapi['info']
          server_code += "# API Title: #{openapi['info']['title']}\n" if openapi['info']['title']
          server_code += "# Version: #{openapi['info']['version']}\n" if openapi['info']['version']
          if openapi['info']['description']
            server_code += "# Description: #{openapi['info']['description'].gsub("\n", "\n# ")}\n"
          end
        end
        server_code += "\nDir.glob(File.join(__dir__, 'models', '*.rb')).each { |f| require f }\n"
        server_code += "Dir.glob(File.join(__dir__, 'daos', '*.rb')).each { |f| require f }\n"
        server_code += "\nrequire_relative 'config/database' " \
                       "if File.exist?(File.join(__dir__, 'config', 'database.rb'))\n"
        server_code += "require_relative 'config/seeder' if File.exist?(File.join(__dir__, 'config', 'seeder.rb'))\n\n"
        server_code += "if defined?(DatabaseConnection) && (ENV['DATABASE_URL'] || ENV['EPHEMERAL_DB'] == 'true')\n"
        server_code += "  DatabaseConnection.connect!\n"
        server_code += "  Seeder.seed_database if $cli_options[:seed] && defined?(Seeder)\nend\n\n"
        server_code += "Dir.glob(File.join(__dir__, 'middlewares', '*.rb')).each { |f| require f }\n"
        server_code += "Dir.glob(File.join(__dir__, 'routes', '*.rb')).each { |f| require f }\n"
        File.write(File.join(out_dir, 'server.rb'), server_code)
        server_code
      end

      # Emits `tests/*.rb` and `mocks/*.rb` into `options[:output]` when `options[:tests]` is set.
      #
      # @param options [Hash] server generation options
      # @param openapi [Hash] parsed OpenAPI specification
      # @return [void]
      def self.emit_server_tests_and_mocks(options, openapi)
        ir = Cdd::IR.new(openapi)
        FileUtils.mkdir_p(File.join(options[:output], 'tests'))
        test_files = Cdd::Tests::Emitter.emit_multiple(ir, options.merge(server: true))
        test_files.each do |filename, t_code|
          full_test_code = "# frozen_string_literal: true\n\nrequire 'minitest'\nrequire 'minitest/autorun'\n" \
                           "require_relative '../server'\n\n#{t_code}"
          File.write(File.join(options[:output], 'tests', filename), full_test_code)
        end

        FileUtils.mkdir_p(File.join(options[:output], 'mocks'))
        mock_files = Cdd::Mocks::Emitter.emit_multiple(ir)
        mock_files.each do |filename, m_code|
          File.write(File.join(options[:output], 'mocks', filename), "# frozen_string_literal: true\n\n#{m_code}")
        end
      end
    end
  end
end
