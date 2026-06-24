# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative '../scaffolding'

module Cdd
  # Server generation module
  module ServerGen
    # Server Emitter
    class Emitter
      # Emits Server
      # @param options [Hash] options
      def self.emit_server(options)
        input_file = options[:input] || Dir.glob("#{options[:input_dir]}/*.json").first
        openapi = JSON.parse(File.read(input_file))

        out_dir = options[:output] || Dir.pwd
        FileUtils.mkdir_p(out_dir)

        Cdd::Scaffolding.generate(options, 'server')

        schemas = openapi.dig('components', 'schemas') || openapi['definitions'] || {}

        # Create subdirectories
        %w[config middlewares models daos routes].each do |dir|
          FileUtils.mkdir_p(File.join(out_dir, dir))
        end

        needs_db = options[:with_ephemeral] || options[:with_seed]

        # 1. Config: CliParser
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

        # 2. Config: Database Connection
        if needs_db
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
            schema['properties']&.each do |prop_name, prop_details|
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

          db_code += <<~RUBY
                end
              end
            end
          RUBY
          File.write(File.join(out_dir, 'config', 'database.rb'), db_code)
        end

        # 3. Models
        schemas.each do |name, schema|
          model_code = "# frozen_string_literal: true\n\n"
          model_code += "require 'active_record'\n\n" if needs_db
          model_code += "# #{name.capitalize} model\n"
          model_code += if needs_db
                          "class #{name.capitalize} < ActiveRecord::Base\n  self.table_name = '#{name.downcase}s'\n"
                        else
                          "class #{name.capitalize}\n"
                        end
          schema['properties']&.each do |prop_name, prop_details|
            model_code += "  # property: #{prop_name} (#{prop_details['type']})\n"
          end
          if schema['discriminator']
            model_code += "  # Discriminator: #{schema['discriminator']['propertyName']}\n"
            model_code += "  # Mapping: #{schema['discriminator']['mapping'].to_json}\n" if schema['discriminator']['mapping']
          end
          model_code += "  # XML Mapping: #{schema['xml'].to_json}\n" if schema['xml']
          model_code += "end\n"
          File.write(File.join(out_dir, 'models', "#{name.downcase}.rb"), model_code)
        end

        # 4. DAOs
        schemas.each_key do |name|
          class_name = name.capitalize
          dao_code = "# frozen_string_literal: true\n\n"
          dao_code += "module Dao\n"
          dao_code += "  # Abstract DAO for #{class_name}\n"
          dao_code += "  class Abstract#{class_name}Dao\n"
          dao_code += "    # Fetch all records\n"
          dao_code += "    def list; raise NotImplementedError; end\n"
          dao_code += "    # Get record by ID\n"
          dao_code += "    # @param id [Integer, String] the record ID\n"
          dao_code += "    def get(id); raise NotImplementedError; end\n"
          dao_code += "    # Create a record\n"
          dao_code += "    # @param params [Hash] attributes\n"
          dao_code += "    def create(params); raise NotImplementedError; end\n"
          dao_code += "    # Update a record\n"
          dao_code += "    # @param id [Integer, String] the record ID\n"
          dao_code += "    # @param params [Hash] attributes\n"
          dao_code += "    def update(id, params); raise NotImplementedError; end\n"
          dao_code += "    # Delete a record\n"
          dao_code += "    # @param id [Integer, String] the record ID\n"
          dao_code += "    def delete(id); raise NotImplementedError; end\n"
          dao_code += "  end\n\n"

          dao_code += "  # Stub DAO for #{class_name}\n"
          dao_code += "  class Stub#{class_name}Dao < Abstract#{class_name}Dao\n"
          dao_code += "    # Fetch all records (Stub)\n"
          dao_code += "    def list; raise NotImplementedError; end\n"
          dao_code += "    # Get record by ID (Stub)\n"
          dao_code += "    # @param id [Integer, String] the record ID\n"
          dao_code += "    def get(id); raise NotImplementedError; end\n"
          dao_code += "    # Create a record (Stub)\n"
          dao_code += "    # @param params [Hash] attributes\n"
          dao_code += "    def create(params); raise NotImplementedError; end\n"
          dao_code += "    # Update a record (Stub)\n"
          dao_code += "    # @param id [Integer, String] the record ID\n"
          dao_code += "    # @param params [Hash] attributes\n"
          dao_code += "    def update(id, params); raise NotImplementedError; end\n"
          dao_code += "    # Delete a record (Stub)\n"
          dao_code += "    # @param id [Integer, String] the record ID\n"
          dao_code += "    def delete(id); raise NotImplementedError; end\n"
          dao_code += "  end\n\n"

          if needs_db
            dao_code += "  # Concrete DAO for #{class_name} backed by ActiveRecord\n"
            dao_code += "  class Concrete#{class_name}Dao < Abstract#{class_name}Dao\n"
            dao_code += "    # Fetch all records (ActiveRecord)\n"
            dao_code += "    def list; ::#{class_name}.all; end\n"
            dao_code += "    # Get record by ID (ActiveRecord)\n"
            dao_code += "    def get(id); ::#{class_name}.find(id); end\n"
            dao_code += "    # Create a record (ActiveRecord)\n"
            dao_code += "    def create(params); ::#{class_name}.create!(params); end\n"
            dao_code += "    # Update a record (ActiveRecord)\n"
            dao_code += "    def update(id, params); record = ::#{class_name}.find(id); record.update!(params); record; end\n"
            dao_code += "    # Delete a record (ActiveRecord)\n"
            dao_code += "    def delete(id); ::#{class_name}.find(id).destroy; end\n"
            dao_code += "  end\n"
          end
          dao_code += "end\n"
          File.write(File.join(out_dir, 'daos', "#{name.downcase}_dao.rb"), dao_code)
        end

        # Factory
        factory_code = "# frozen_string_literal: true\n\nmodule Dao\n"
        factory_code += "  # Factory to get DAO implementations based on environment\n"
        factory_code += "  class Factory\n"
        schemas.each_key do |name|
          class_name = name.capitalize
          factory_code += "    # Get #{class_name} DAO\n"
          factory_code += "    # @return [Abstract#{class_name}Dao] the configured DAO\n"
          factory_code += "    def self.#{name.downcase}_dao\n"
          if needs_db
            factory_code += "      if ENV['DATABASE_URL'] || ENV['EPHEMERAL_DB'] == 'true' || ARGV.include?('--ephemeral')\n"
            factory_code += "        Concrete#{class_name}Dao.new\n"
            factory_code += "      else\n"
            factory_code += "        Stub#{class_name}Dao.new\n"
            factory_code += "      end\n"
          else
            factory_code += "      Stub#{class_name}Dao.new\n"
          end
          factory_code += "    end\n\n"
        end
        factory_code += "  end\nend\n"
        File.write(File.join(out_dir, 'daos', 'factory.rb'), factory_code)

        # 5. Seeder
        if options[:with_seed]
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
            seeder_code += "  # Factory for #{name}\n"
            seeder_code += "  # @return [Hash] the attributes for the new record\n"
            seeder_code += "  def self.generate_#{name.downcase}\n"
            seeder_code += "    {\n"
            schema['properties']&.each do |prop_name, prop_details|
              next if prop_name == 'id'

              is_fk = prop_name.match(/^(.*)[_I]d$/)
              val = if is_fk
                      parent_model = is_fk[1].downcase
                      "(@pool[:#{parent_model}] && !@pool[:#{parent_model}].empty?) ? @pool[:#{parent_model}].sample : rand(1..1000)"
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
              seeder_code += "      #{prop_name}: #{val},\n"
            end
            seeder_code += "    }\n"
            seeder_code += "  end\n\n"
          end

          seeder_code += "  # Seeds the database with fake data.\n"
          seeder_code += "  # @param dao_factory [Class] the DAO factory to use for creation\n"
          seeder_code += "  # @return [void]\n"
          seeder_code += "  def self.seed_database(dao_factory = Dao::Factory)\n"

          sorted_names = schemas.keys.sort_by do |n|
            schemas[n]['properties']&.keys&.count { |p| p.match(/[_I]d$/) } || 0
          end

          sorted_names.each do |name|
            seeder_code += "    @pool[:#{name.downcase}] = []\n"
            seeder_code += "    10.times do\n"
            seeder_code += "      record = dao_factory.#{name.downcase}_dao.create(generate_#{name.downcase})\n"
            seeder_code += "      @pool[:#{name.downcase}] << record.id if record.respond_to?(:id)\n"
            seeder_code += "    end\n"
          end
          seeder_code += "  end\n"
          seeder_code += "end\n"
          File.write(File.join(out_dir, 'config', 'seeder.rb'), seeder_code)
        end

        # 6. Middlewares
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

        auth_code = "# frozen_string_literal: true\n\nrequire 'sinatra'\nrequire 'json'\n\n"
        if openapi['components'] && openapi['components']['securitySchemes']
          auth_code += "# Security Middleware\n"
          auth_code += "before do\n"
          auth_code += "  pass if request.path_info == '/mcp/sse' || request.path_info == '/mcp/message'\n"
          auth_code += "  pass if request.path_info.start_with?('/auth/')\n"
          auth_code += "  if $cli_options[:enforce_auth] || (ENV['EPHEMERAL_DB'] == 'true')\n"
          auth_code += "    auth_header = request.env['HTTP_AUTHORIZATION'] || request.env['HTTP_API_KEY']\n"
          auth_code += "    halt 401, { error: 'Unauthorized' }.to_json unless auth_header && auth_header.include?('mock-token')\n"

          if needs_db
            auth_code += "  elsif ENV['DATABASE_URL'] && ENV['EPHEMERAL_DB'] != 'true'\n"
            auth_code += "    auth_header = request.env['HTTP_AUTHORIZATION'] || request.env['HTTP_API_KEY']\n"
            auth_code += "    halt 401, { error: 'Unauthorized' }.to_json unless auth_header\n"
            auth_code += "    token = auth_header.gsub('Bearer ', '')\n"
            auth_code += "    begin\n"
            auth_code += "      user = Dao::Factory.user_dao.list.find { |u| u.respond_to?(:password) && u.password == token }\n"
            auth_code += "      halt 403, { error: 'Forbidden: Invalid Token' }.to_json unless user\n"
            auth_code += "    rescue StandardError\n"
            auth_code += "    end\n"
          end
          auth_code += "  end\n"
          auth_code += "end\n"
        end
        File.write(File.join(out_dir, 'middlewares', 'auth.rb'), auth_code)

        # 7. Routes
        # Auth Routes
        auth_routes = "# frozen_string_literal: true\n\nrequire 'sinatra'\nrequire 'json'\n\n"
        auth_routes += "# Integrated Identity Provider (IdP) module\n"
        auth_routes += "if $cli_options[:start_auth_server]\n"
        auth_routes += "  post '/auth/register' do\n"
        auth_routes += "    content_type :json\n"
        auth_routes += "    begin\n"
        auth_routes += "      req = JSON.parse(request.body.read)\n"
        if needs_db
          auth_routes += "      user = Dao::Factory.user_dao.create(req)\n"
          auth_routes += "      { message: 'Registered Successfully', id: user.respond_to?(:id) ? user.id : 'generated' }.to_json\n"
        else
          auth_routes += "      { message: 'Registered Successfully (Stub)', id: 'stub' }.to_json\n"
        end
        auth_routes += "    rescue StandardError => e\n"
        auth_routes += "      halt 400, { error: e.message }.to_json\n"
        auth_routes += "    end\n"
        auth_routes += "  end\n\n"
        auth_routes += "  post '/auth/login' do\n"
        auth_routes += "    content_type :json\n"
        auth_routes += "    begin\n"
        auth_routes += "      req = JSON.parse(request.body.read)\n"
        if needs_db
          auth_routes += "      user = Dao::Factory.user_dao.list.find { |u| u.respond_to?(:username) && u.username == req['username'] }\n"
          auth_routes += "      if user && user.respond_to?(:password) && user.password == req['password']\n"
          auth_routes += "        { token: user.password }.to_json\n"
        else
          auth_routes += "      if req['username'] == 'admin' && req['password'] == 'password'\n"
          auth_routes += "        { token: 'mock-token-123' }.to_json\n"
        end
        auth_routes += "      else\n"
        auth_routes += "        halt 401, { error: 'Invalid Credentials' }.to_json\n"
        auth_routes += "      end\n"
        auth_routes += "    rescue StandardError => e\n"
        auth_routes += "      halt 400, { error: e.message }.to_json\n"
        auth_routes += "    end\n"
        auth_routes += "  end\n\n"
        auth_routes += "  post '/auth/refresh' do\n"
        auth_routes += "    content_type :json\n"
        auth_routes += "    { token: 'mock-token-123' }.to_json\n"
        auth_routes += "  end\n\n"
        auth_routes += "  post '/auth/logout' do\n"
        auth_routes += "    content_type :json\n"
        auth_routes += "    { message: 'Logged out' }.to_json\n"
        auth_routes += "  end\n"
        auth_routes += "end\n"
        File.write(File.join(out_dir, 'routes', 'auth_routes.rb'), auth_routes)

        # Webhook Admin Routes
        has_webhooks = openapi['webhooks'] && !openapi['webhooks'].empty?
        has_callbacks = openapi['components'] && openapi['components']['callbacks'] && !openapi['components']['callbacks'].empty?

        wh_code = "# frozen_string_literal: true\n\nrequire 'sinatra'\nrequire 'json'\nrequire 'net/http'\nrequire 'uri'\n\n"
        if has_webhooks || has_callbacks
          wh_code += "# Administrative Webhook Trigger API\n"
          wh_code += "post '/_mock/trigger-webhook/:name' do\n"
          wh_code += "  content_type :json\n"
          wh_code += "  begin\n"
          wh_code += "    req = JSON.parse(request.body.read)\n"
          wh_code += "    target_url = req['target_url'] || params[:target_url]\n"
          wh_code += "    halt 400, { error: 'Missing target_url' }.to_json unless target_url\n"
          wh_code += "    uri = URI(target_url)\n"
          wh_code += "    payload = { event: params[:name], data: 'mock_payload' }.to_json\n"
          wh_code += "    http_req = Net::HTTP::Post.new(uri)\n"
          wh_code += "    http_req['Content-Type'] = 'application/json'\n"
          wh_code += "    http_req.body = payload\n"
          wh_code += "    Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|\n"
          wh_code += "      http.request(http_req)\n"
          wh_code += "    end\n"
          wh_code += "    { message: 'Webhook Dispatched' }.to_json\n"
          wh_code += "  rescue StandardError => e\n"
          wh_code += "    halt 500, { error: e.message }.to_json\n"
          wh_code += "  end\n"
          wh_code += "end\n"
        end
        File.write(File.join(out_dir, 'routes', 'webhook_routes.rb'), wh_code)

        # Domain Routes
        domain_routes_map = {}
        openapi['paths']&.each do |path, methods|
          sinatra_path = path.gsub(/\{([^}]+)\}/, ':\1')
          possible_resources = path.split('/').reject { |p| p.empty? || p.include?('{') || %w[api v1 v2 v3 v4].include?(p.downcase) }
          model_hint = possible_resources.first

          model_name = nil
          if model_hint
            singular = model_hint.end_with?('s') ? model_hint[0...-1] : model_hint
            match = schemas.keys.find { |k| k.downcase == singular.downcase || k.downcase == model_hint.downcase }
            model_name = match if match
          end

          file_key = model_name ? model_name.downcase : 'general'
          domain_routes_map[file_key] ||= "# frozen_string_literal: true\n\nrequire 'sinatra'\nrequire 'json'\n\n"

          methods.each do |method, details|
            r_code = "# Operation: #{details['operationId'] || method.upcase}\n"
            r_code += "# Summary: #{details['summary']}\n" if details['summary']
            r_code += "# Description: #{details['description']}\n" if details['description']
            r_code += "# Deprecated: true\n" if details['deprecated']

            path_param = nil
            details['parameters']&.each do |param|
              req = param['required'] ? 'required' : 'optional'
              r_code += "# Param [#{param['in']}]: #{param['name']} (#{req})\n"
              path_param = param['name'] if param['in'] == 'path' && path_param.nil?
            end

            if details['requestBody']
              r_code += "# Request Body: expected\n"
              details['requestBody']['content']&.each_key do |mt|
                r_code += "# Content-Type: #{mt}\n"
              end
            end

            r_code += "#{method.downcase} '#{sinatra_path}' do\n"
            r_code += "  content_type :json\n"

            if model_name
              r_code += "  begin\n"
              r_code += "    dao = Dao::Factory.#{model_name.downcase}_dao\n"

              case method.downcase
              when 'get'
                if path_param
                  r_code += "    record = dao.get(params[:#{path_param}])\n"
                  r_code += "    halt 404, { error: 'Not found' }.to_json unless record\n"
                  r_code += "    record.to_json\n"
                else
                  r_code += "    dao.list.to_json\n"
                end
              when 'post'
                r_code += "    req_body = JSON.parse(request.body.read) rescue {}\n"
                r_code += "    dao.create(req_body).to_json\n"
              when 'put', 'patch'
                if path_param
                  r_code += "    req_body = JSON.parse(request.body.read) rescue {}\n"
                  r_code += "    dao.update(params[:#{path_param}], req_body).to_json\n"
                else
                  r_code += "    { message: 'Not implemented (missing ID)' }.to_json\n"
                end
              when 'delete'
                if path_param
                  r_code += "    dao.delete(params[:#{path_param}])\n"
                  r_code += "    status 204\n"
                  r_code += "    ''\n"
                else
                  r_code += "    { message: 'Not implemented (missing ID)' }.to_json\n"
                end
              else
                r_code += "    { message: 'Not implemented' }.to_json\n"
              end

              r_code += "  rescue NotImplementedError\n"
              r_code += "    halt 501, { message: 'Not implemented' }.to_json\n"
              r_code += "  rescue StandardError => e\n"
              r_code += "    halt 400, { error: e.message }.to_json\n"
              r_code += "  end\n"
            else
              r_code += "  halt 501, { message: 'Not implemented' }.to_json\n"
            end

            r_code += "end\n\n"
            domain_routes_map[file_key] += r_code
          end
        end

        domain_routes_map.each do |key, code|
          File.write(File.join(out_dir, 'routes', "#{key}_routes.rb"), code)
        end

        # MCP Routes
        tools_array = []
        openapi['paths']&.each do |path, methods|
          methods.each do |method, details|
            operation_id = details['operationId'] || "#{method}_#{path.gsub(/[^a-zA-Z0-9]/, '_')}"
            tool = {
              name: operation_id,
              description: details['summary'] || "Call #{method.upcase} #{path}",
              inputSchema: { type: 'object', properties: {}, required: [] }
            }
            details['parameters']&.each do |param|
              tool[:inputSchema][:properties][param['name']] = { type: 'string', description: param['in'] }
              tool[:inputSchema][:required] << param['name'] if param['required']
            end
            tools_array << tool
          end
        end
        mcp_code = "# frozen_string_literal: true\n\nrequire 'sinatra'\nrequire 'json'\n\n"
        mcp_code += "set :mcp_connections, []\n"
        mcp_code += "get '/mcp/sse' do\n"
        mcp_code += "  content_type 'text/event-stream'\n"
        mcp_code += "  stream(:keep_open) do |out|\n"
        mcp_code += "    settings.mcp_connections << out\n"
        mcp_code += "    out << \"event: endpoint\\ndata: /mcp/message\\n\\n\"\n"
        mcp_code += "    out.callback { settings.mcp_connections.delete(out) }\n"
        mcp_code += "  end\n"
        mcp_code += "end\n\n"
        mcp_code += "post '/mcp/message' do\n"
        mcp_code += "  begin\n"
        mcp_code += "    req = JSON.parse(request.body.read)\n"
        mcp_code += "  rescue JSON::ParserError\n"
        mcp_code += "    status 202\n"
        mcp_code += "    resp = { jsonrpc: '2.0', error: { code: -32700, message: 'Parse error' } }\n"
        mcp_code += "    settings.mcp_connections.each { |out| out << \"event: message\\ndata: \#{resp.to_json}\\n\\n\" }\n"
        mcp_code += "    return\n"
        mcp_code += "  end\n"
        mcp_code += "  if req['id'].nil?\n"
        mcp_code += "    if req['method'] == 'notifications/cancelled'\n"
        mcp_code += "      # Cancelled request\n"
        mcp_code += "    end\n"
        mcp_code += "    return\n"
        mcp_code += "  end\n"
        mcp_code += "  resp = { jsonrpc: '2.0', id: req['id'], result: { _meta: {} } }\n"
        mcp_code += "  if req['method'] == 'initialize'\n"
        mcp_code += "    resp[:result] = { capabilities: { tools: { listChanged: true }, logging: {}, experimental: {}, roots: { listChanged: true }, sampling: {} }, serverInfo: { name: 'mcp-server', version: '1.0.0' }, protocolVersion: '2024-11-05', instructions: '' }\n"
        mcp_code += "  elsif req['method'] == 'ping'\n"
        mcp_code += "    resp[:result] = {}\n"
        mcp_code += "  elsif req['method'] == 'logging/setLevel'\n"
        mcp_code += "    resp[:result] = {}\n"
        mcp_code += "  elsif req['method'] == 'roots/list'\n"
        mcp_code += "    resp[:result] = { roots: [] }\n"
        mcp_code += "  elsif req['method'] == 'resources/templates/list'\n"
        mcp_code += "    resp[:result] = { resourceTemplates: [] }\n"
        mcp_code += "  elsif req['method'] == 'sampling/createMessage'\n"
        mcp_code += "    resp[:result] = { role: 'assistant', model: 'stub-model', content: { type: 'text', text: 'sampled' } }\n"
        mcp_code += "  elsif req['method'] == 'completion/complete'\n"
        mcp_code += "    resp[:result] = { completion: { values: [], total: 0, hasMore: false } }\n"
        mcp_code += "  elsif req['method'] == 'tools/list'\n"
        mcp_code += "    resp[:result] = { tools: #{tools_array.to_json} }\n"
        mcp_code += "  elsif req['method'] == 'tools/call'\n"
        mcp_code += "    resp[:result] = { content: [{ type: 'text', text: 'Calling tool ' + req.dig('params', 'name').to_s }] }\n"
        mcp_code += "  else\n"
        mcp_code += "    resp = { jsonrpc: '2.0', id: req['id'], error: { code: -32601, message: 'Method not found' } }\n"
        mcp_code += "  end\n"
        mcp_code += "  settings.mcp_connections.each { |out| out << \"event: message\\ndata: \#{resp.to_json}\\n\\n\" }\n"
        mcp_code += "  status 202\n"
        mcp_code += "end\n"
        File.write(File.join(out_dir, 'routes', 'mcp_routes.rb'), mcp_code)

        # 8. Server Entrypoint (server.rb)
        server_code = "# frozen_string_literal: true\n\n"
        server_code += "$cli_options ||= {}\n"
        server_code += "require_relative 'config/cli_parser'\n"
        server_code += "$cli_options = CliParser.parse(ARGV) if ARGV.any?\n\n"
        server_code += "require 'sinatra'\n"
        server_code += "require 'json'\n\n"
        server_code += "set :server, :puma\n\n"
        if openapi['info']
          server_code += "# API Title: #{openapi['info']['title']}\n" if openapi['info']['title']
          server_code += "# Version: #{openapi['info']['version']}\n" if openapi['info']['version']
          server_code += "# Description: #{openapi['info']['description'].gsub("\n", "\n# ")}\n" if openapi['info']['description']
        end

        server_code += "\nDir.glob(File.join(__dir__, 'models', '*.rb')).each { |f| require f }\n"
        server_code += "Dir.glob(File.join(__dir__, 'daos', '*.rb')).each { |f| require f }\n"

        server_code += "\nrequire_relative 'config/database' if File.exist?(File.join(__dir__, 'config', 'database.rb'))\n"
        server_code += "require_relative 'config/seeder' if File.exist?(File.join(__dir__, 'config', 'seeder.rb'))\n\n"

        server_code += "if defined?(DatabaseConnection) && (ENV['DATABASE_URL'] || ENV['EPHEMERAL_DB'] == 'true')\n"
        server_code += "  DatabaseConnection.connect!\n"
        server_code += "  Seeder.seed_database if $cli_options[:seed] && defined?(Seeder)\n"
        server_code += "end\n\n"

        server_code += "Dir.glob(File.join(__dir__, 'middlewares', '*.rb')).each { |f| require f }\n"
        server_code += "Dir.glob(File.join(__dir__, 'routes', '*.rb')).each { |f| require f }\n"

        File.write(File.join(out_dir, 'server.rb'), server_code)

        # We also need to emit tests if options[:tests] is true
        if options[:tests]
          ir = Cdd::IR.new
          ir.openapi_spec = openapi

          FileUtils.mkdir_p(File.join(options[:output], 'tests'))
          test_files = Cdd::Tests::Emitter.emit_multiple(ir, options.merge(server: true))
          test_files.each do |filename, t_code|
            full_test_code = "# frozen_string_literal: true\n\nrequire 'minitest'\nrequire 'minitest/autorun'\nrequire_relative '../server'\n\n#{t_code}"
            File.write(File.join(options[:output], 'tests', filename), full_test_code)
          end

          FileUtils.mkdir_p(File.join(options[:output], 'mocks'))
          mock_files = Cdd::Mocks::Emitter.emit_multiple(ir)
          mock_files.each do |filename, m_code|
            full_mock_code = "# frozen_string_literal: true\n\n#{m_code}"
            File.write(File.join(options[:output], 'mocks', filename), full_mock_code)
          end
        end

        server_code
      end

      # Supported keys
      # @return [Array]
      def self._supported_keys
        %w[jsonSchemaDialect termsOfService contact license name url email identifier
           variables enum default description schemas responses parameters examples requestBodies headers securitySchemes links callbacks pathItems mediaTypes summary get put post delete options head patch trace query additionalOperations operationId requestBody deprecated security in required allowEmptyValue example style explode allowReserved schema content itemSchema encoding prefixEncoding itemEncoding contentType 200 expression dataValue serializedValue externalValue value operationRef server parent kind discriminator xml propertyName mapping defaultMapping nodeType namespace prefix attribute wrapped type scheme bearerFormat flows openIdConnectUrl oauth2MetadataUrl implicit password clientCredentials authorizationCode deviceAuthorization authorizationUrl deviceAuthorizationUrl tokenUrl refreshUrl scopes]
      end
    end
  end
end
