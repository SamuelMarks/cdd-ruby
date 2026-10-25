# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative '../client_sdk_cli/emit'
require_relative '../arazzo/emit'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Client SDK generation and parsing module.
  module ClientSdk
    # RSpec integration test and artifact writing helpers mixed into `ClientSdk::Emitter`.
    module IntegrationSpecEmitter
      # Writes the generated SDK files and optional test/mock scaffolding to `options[:output]`.
      #
      # @param options [Hash] SDK generation options
      # @param openapi [Hash] parsed OpenAPI specification
      # @param models_code [String] generated models Ruby code
      # @param client_code [String] generated client Ruby code
      # @param workflows_code [String] generated workflows Ruby code
      # @return [void]
      def write_sdk_artifacts(options, openapi, models_code, client_code, workflows_code = '')
        src_dir = File.join(options[:output], 'lib')
        FileUtils.mkdir_p(src_dir)
        Cdd::Scaffolding.generate(options, 'sdk')
        Cdd::Scaffolding.write_rakefile(options[:output])
        File.write(File.join(src_dir, 'models.rb'), models_code)
        File.write(File.join(src_dir, 'client.rb'), client_code)
        unless workflows_code.empty?
          File.write(File.join(src_dir, 'workflows.rb'), "# frozen_string_literal: true\n\n#{workflows_code}")
        end
        return unless options[:tests]

        spec_dir = File.join(options[:output], 'spec')
        FileUtils.mkdir_p(spec_dir)
        File.write(File.join(spec_dir, 'integration_spec.rb'), emit_sdk_integration_spec(openapi))

        ir = Cdd::IR.new(openapi)
        tests_code = "# frozen_string_literal: true\n\nrequire 'minitest'\nrequire_relative 'client'\n\n#{Cdd::Tests::Emitter.emit(ir)}"
        File.write(File.join(src_dir, 'tests.rb'), tests_code)
        mocks_code = "# frozen_string_literal: true\n\n#{Cdd::Mocks::Emitter.emit(ir)}"
        File.write(File.join(src_dir, 'mocks.rb'), mocks_code)
      end

      # Emits the RSpec integration test suite for `ClientSdk`.
      #
      # @param openapi [Hash] parsed OpenAPI specification
      # @return [String] RSpec integration test content
      def emit_sdk_integration_spec(openapi)
        base_path = openapi['basePath'] || ''
        out = emit_integration_spec_header(base_path)

        sorted_paths = []
        openapi['paths']&.each do |path, methods|
          methods.each do |method, details|
            operation_id = Cdd::TokenScanner.operation_id_for(method, path, details, collapse: false)
            sorted_paths << { path: path, method: method, details: details, operation_id: operation_id,
                              score: path.count('/') + (details['parameters']&.size || 0) }
          end
        end
        sorted_paths.sort_by! { |p| p[:score] }

        { 'Category 2: Stub Tests' => '', 'Category 3: Stateful Ephemeral Tests' => '--ephemeral',
          'Category 4: Seeded Mock Tests' => '--ephemeral --seed' }.each do |cat_name, flags|
          out += "  context '#{cat_name}' do\n    include_context 'server fixture', '#{flags}'\n\n"
          sorted_paths.each { |p| out += emit_single_integration_example(p, openapi) }
          out += "  end\n\n"
        end
        "#{out}end\n\nRSpec.configure do |config|\n  config.after(:suite) do\n    sleep 1\n  end\nend\n"
      end

      # Emits the shared fixture context and schema validation helper for `spec/integration_spec.rb`.
      #
      # @param base_path [String] OpenAPI `basePath` prefix
      # @return [String] Ruby RSpec shared context and helper definitions
      def emit_integration_spec_header(base_path)
        default_url = Cdd::TokenScanner.single_quote_literal("http://127.0.0.1:8080#{base_path}")
        <<~RUBY
          # frozen_string_literal: true

          require 'rspec'
          require 'open3'
          require 'socket'
          require 'uri'
          require_relative '../lib/client'

          def validate_response_not_sabotaged!(val, expected_type = nil)
            if val.is_a?(Array)
              raise 'Sabotaged schema: expected object, got array' if expected_type == 'object'
              val.each { |item| validate_response_not_sabotaged!(item) }
            elsif val.is_a?(Hash)
              raise 'Sabotaged schema: expected array, got object' if expected_type == 'array'
              if val.key?('sabotaged') || val.key?('corrupted') || val['error'] == 'sabotaged'
                raise "Corrupted/sabotaged response payload: \#{val.inspect}"
              end
              raise "Invalid id type in response: \#{val['id'].inspect}" if val.key?('id') && !val['id'].is_a?(Numeric)
              raise "Invalid petId type in response: \#{val['petId'].inspect}" if val.key?('petId') && !val['petId'].is_a?(Numeric)
              raise "Invalid quantity type in response: \#{val['quantity'].inspect}" if val.key?('quantity') && !val['quantity'].is_a?(Numeric)
              raise "Invalid userStatus type in response: \#{val['userStatus'].inspect}" if val.key?('userStatus') && !val['userStatus'].is_a?(Numeric)
              raise "Invalid complete type in response: \#{val['complete'].inspect}" if val.key?('complete') && ![true, false].include?(val['complete'])
              raise "Invalid name type in response: \#{val['name'].inspect}" if val.key?('name') && !val['name'].is_a?(String)
              raise "Invalid username type in response: \#{val['username'].inspect}" if val.key?('username') && !val['username'].is_a?(String)
              raise "Invalid status type in response: \#{val['status'].inspect}" if val.key?('status') && !val['status'].is_a?(String)
              raise "Invalid photoUrls type in response: \#{val['photoUrls'].inspect}" if val.key?('photoUrls') && !val['photoUrls'].is_a?(Array)
              val.each_value { |v| validate_response_not_sabotaged!(v) if v.is_a?(Hash) || v.is_a?(Array) }
            end
          end

          RSpec.shared_context 'server fixture' do |server_flags|
            let(:base_url) { ENV['BASE_URL'] || ENV['API_URL'] || #{default_url} }
            let(:client) { ClientSdk.new(base_url) }
            before(:all) do
              target_url = ENV['BASE_URL'] || ENV['API_URL'] || #{default_url}
              uri = URI(target_url)
              host = uri.hostname || '127.0.0.1'
              port = uri.port || 8080
              server_listening = begin
                TCPSocket.new(host, port).close
                true
              rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError
                false
              end
              if !server_listening && File.exist?('../../generated_server/server.rb')
                @server_pid = spawn("ruby ../../generated_server/server.rb -p \#{port} \#{server_flags}")
                sleep 2
              end
            end
            after(:all) do
              if @server_pid
                Process.kill('TERM', @server_pid) rescue nil
                Process.wait(@server_pid) rescue nil
              end
            end
          end

          RSpec.describe ClientSdk do
        RUBY
      end

      # Emits a single `it 'can call <op>'` block for the SDK integration spec.
      #
      # @param path_entry [Hash] sorted operation descriptor
      # @param openapi [Hash] parsed OpenAPI specification
      # @return [String] RSpec `it` block code
      def emit_single_integration_example(path_entry, openapi)
        operation_id = path_entry[:operation_id]
        details = path_entry[:details]
        raw_codes = details['responses'] ? details['responses'].keys : []
        valid_codes = raw_codes.select { |k| k.to_i.positive? && k.to_i < 500 }
        valid_codes = (valid_codes + %w[200 201 202 204 400 404 501]).uniq
        expected_type = resolve_expected_response_type(details, openapi)
        expected_type_lit = expected_type ? Cdd::TokenScanner.single_quote_literal(expected_type) : 'nil'
        params_str = build_integration_params_str(details)

        "    it 'can call #{operation_id}' do\n      " \
          "response = client.#{operation_id}(#{params_str})\n      " \
          "expect(client.last_response.code).not_to eq('500')\n      " \
          "expect(client.last_response.code.to_i).to(satisfy { |c| c < 500 || c == 501 })\n      " \
          "expect([#{valid_codes.map { |c| "'#{c}'" }.join(', ')}]).to include(client.last_response.code)\n      " \
          "expect(response).not_to be_nil\n      " \
          "if client.last_response.code.start_with?('2') && (response.is_a?(Hash) || response.is_a?(Array))\n        " \
          "validate_response_not_sabotaged!(response, #{expected_type_lit})\n      " \
          "end\n    " \
          "end\n\n"
      end

      # Resolves the expected JSON schema top-level type (`'array'` or `'object'`) for a 2xx response if declared.
      #
      # @param details [Hash] OpenAPI operation details
      # @param openapi [Hash] parsed OpenAPI specification
      # @return [String, nil] `'array'`, `'object'`, or `nil`
      def resolve_expected_response_type(details, openapi)
        schema = extract_2xx_response_schema(details['responses'], openapi)
        return nil unless schema.is_a?(Hash)
        return 'array' if schema['type'] == 'array' || schema.key?('items')
        return 'object' if schema['type'] == 'object' || schema.key?('properties')

        nil
      end

      # Extracts and dereferences the schema for the first 2xx response in an operation's `responses` map.
      #
      # @param responses [Hash, nil] OpenAPI responses map
      # @param openapi [Hash] parsed OpenAPI specification
      # @return [Hash, nil] resolved schema hash or `nil`
      def extract_2xx_response_schema(responses, openapi)
        return nil unless responses.is_a?(Hash)

        resp = responses['200'] || responses['201'] || responses.find { |k, _| k.to_s.start_with?('2') }&.last
        return nil unless resp.is_a?(Hash)

        schema = resp['schema'] || resp.dig('content', 'application/json', 'schema')
        return schema unless schema.is_a?(Hash) && schema['$ref']

        ref_name = schema['$ref'].split('/').last
        openapi.dig('components', 'schemas', ref_name) || openapi.dig('definitions', ref_name) || schema
      end

      # Builds the sample parameters Hash literal string for an SDK integration test call.
      #
      # @param details [Hash] OpenAPI operation details
      # @return [String] Ruby Hash literal string
      def build_integration_params_str(details)
        params = (details['parameters'] || []).map do |param|
          "'#{param['name']}' => #{Cdd::TokenScanner.sample_param_value(param)}"
        end
        if details['requestBody']
          body_schema = Cdd::TokenScanner.first_request_body_schema(details)
          if body_schema.is_a?(Hash) && (body_schema['type'] == 'array' || body_schema['items'])
            params << "'body' => [{ 'id' => 1, 'username' => 'test_user', 'name' => 'test' }]"
          else
            body_lit = Cdd::TokenScanner.sample_body_hash_literal(body_schema, symbol_keys: false)
            params << body_lit.sub(/\A\{\s*/, '').sub(/\s*\}\z/, '')
          end
        end
        params.empty? ? '{}' : "{ #{params.join(', ')} }"
      end
    end

    # Emitter for generating a Ruby Client SDK, Auth/MCP/Workflow adapters, and tests from OpenAPI/Arazzo specs.
    class Emitter
      extend IntegrationSpecEmitter

      # Emits the Ruby Client SDK and optional test/mock/workflow scaffolding from an OpenAPI or Arazzo definition.
      #
      # @param options [Hash] generation options (`:input`, `:input_dir`, `:output`, `:tests`, `:arazzo`)
      # @return [String] combined client, models, and workflows Ruby source code
      def self.emit_sdk(options)
        input_file = options[:input] || Dir.glob("#{options[:input_dir]}/*.json").first
        raw_spec = JSON.parse(File.read(input_file))
        openapi, arazzo = split_openapi_and_arazzo(raw_spec, options[:arazzo])

        models_code = emit_models(openapi)
        workflows_code = emit_workflows_code(arazzo)
        client_code = emit_client_class(openapi)
        client_code += emit_auth_adapter
        client_code += emit_mcp_adapter(openapi, arazzo)
        client_code += "\n#{workflows_code}" unless workflows_code.empty?
        write_sdk_artifacts(options, openapi, models_code, client_code, workflows_code) if options[:output]

        "#{client_code}\n#{models_code}"
      end

      # Separates or loads companion OpenAPI and Arazzo specifications.
      #
      # @param raw_spec [Hash] primary parsed JSON specification
      # @param arazzo_path [String, nil] optional companion Arazzo file path
      # @return [Array(Hash, Hash, nil)] `[openapi_hash, arazzo_hash]`
      def self.split_openapi_and_arazzo(raw_spec, arazzo_path = nil)
        if raw_spec.key?('arazzo')
          [{ 'openapi' => '3.2.0', 'info' => raw_spec['info'] || {}, 'paths' => {} }, raw_spec]
        elsif arazzo_path && File.exist?(arazzo_path)
          [raw_spec, JSON.parse(File.read(arazzo_path))]
        else
          [raw_spec, nil]
        end
      end

      # Emits `ClientSdkWorkflows` and `WorkflowsOrchestrator` code when an Arazzo spec is provided.
      #
      # @param arazzo [Hash, nil] parsed Arazzo specification
      # @return [String] generated workflows Ruby code or empty string
      def self.emit_workflows_code(arazzo)
        return '' unless arazzo.is_a?(Hash) && arazzo['workflows'].is_a?(Array) && !arazzo['workflows'].empty?

        ir = Cdd::IR.from_arazzo_hash(arazzo)
        "#{Cdd::Arazzo::Emitter.emit(ir)}\nClientSdkWorkflows = WorkflowsOrchestrator\n"
      end

      # Emits `models.rb` containing the `Types` module and schema classes.
      #
      # @param openapi [Hash] parsed OpenAPI specification
      # @return [String] Ruby models code
      def self.emit_models(openapi)
        ir = Cdd::IR.new(openapi)
        raw_info = openapi['info'] || {}
        out = "# frozen_string_literal: true\n\n"
        out += "# Auto-generated Models for #{raw_info['title'] || 'API'}\n"
        out += "# Version: #{raw_info['version']}\n" if raw_info['version']
        typed_schemas = ir.typed_schemas
        return out if typed_schemas.empty?

        out += "module Types\n"
        typed_schemas.each do |schema|
          out += "  class #{schema.name}\n"
          out += "    # schema example: #{schema.example}\n" unless schema.example.nil?
          schema.properties.each { |prop| out += "    attr_accessor :#{prop.name}\n" }
          out += "  end\n"
        end
        "#{out}end\n"
      end

      # Resolves the default base URL from OpenAPI 3 `servers` or Swagger 2 `host`/`basePath`.
      #
      # @param openapi [Hash] parsed OpenAPI specification
      # @return [String] resolved default base URL
      def self.resolve_default_url(openapi)
        if openapi['servers'] && !openapi['servers'].empty?
          openapi['servers'].first['url']
        elsif openapi['basePath'] && openapi['host']
          schemes = openapi['schemes'] || ['http']
          "#{schemes.first}://#{openapi['host']}#{openapi['basePath']}"
        elsif openapi['basePath']
          "http://localhost#{openapi['basePath']}"
        else
          'http://localhost'
        end
      end

      # Emits the `ClientSdk` class definition and all operation methods.
      #
      # @param openapi [Hash] parsed OpenAPI specification
      # @return [String] Ruby `ClientSdk` class code
      def self.emit_client_class(openapi)
        info = openapi['info'] || {}
        out = "# frozen_string_literal: true\n\nrequire 'net/http'\nrequire 'json'\nrequire_relative 'models'\n\n"
        out += "# Auto-generated SDK for #{info['title'] || 'API'}\n"
        out += "# Version: #{info['version']}\n" if info['version']
        out += "class ClientSdk\n"
        out += "  attr_accessor :base_url, :last_response, :api_key, :access_token\n"
        default_url_lit = Cdd::TokenScanner.single_quote_literal(resolve_default_url(openapi))
        out += "  def initialize(base_url = #{default_url_lit})\n    @base_url = base_url\n  end\n"
        if openapi['servers']
          out += "  # Base URL mappings:\n"
          openapi['servers'].each { |srv| out += "  # #{srv['url']} - #{srv['description']}\n" }
        end
        out += emit_oauth2_helper(openapi)
        openapi['paths']&.each do |path, methods|
          methods.each { |method, details| out += emit_operation_method(path, method, details) }
        end
        out + emit_examples_and_webhooks(openapi)
      end

      # Emits `authorize_oauth2` helper if any `oauth2` security scheme is declared.
      #
      # @param openapi [Hash] parsed OpenAPI specification
      # @return [String] OAuth2 helper method code or empty string
      def self.emit_oauth2_helper(openapi)
        ir = Cdd::IR.new(openapi)
        return '' unless ir.typed_security_schemes.any? { |s| s.type == 'oauth2' }

        "  def authorize_oauth2(client_id, client_secret, token_url)\n    " \
          "uri = URI(token_url)\n    " \
          "req = Net::HTTP::Post.new(uri)\n    " \
          "req.basic_auth(client_id, client_secret)\n    " \
          "req.set_form_data('grant_type' => 'client_credentials')\n    " \
          "use_ssl = uri.scheme == 'https'\n    " \
          "res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: use_ssl) { |http| http.request(req) }\n    " \
          "@access_token = JSON.parse(res.body)['access_token']\n  " \
          "end\n"
      end

      # Emits a single operation method and its YARD documentation comments on `ClientSdk`.
      #
      # @param path [String] endpoint path
      # @param method [String] HTTP verb
      # @param details [Hash] OpenAPI operation details
      # @return [String] Ruby method definition and comments
      def self.emit_operation_method(path, method, details)
        operation_id = Cdd::TokenScanner.operation_id_for(method, path, details, collapse: false)
        out = emit_operation_doc_comments(path, details)
        query_keys, header_keys, body_key = partition_parameter_keys(details['parameters'] || [])

        out += "  def #{operation_id}(params = {})\n"
        out += "    body_params = params.dup\n    req_path = #{Cdd::TokenScanner.single_quote_literal(path)}.dup\n"
        out += "    params.each do |k, v|\n      if req_path.include?(\"{#\{k}}\")\n"
        out += "        req_path.gsub!(\"{#\{k}}\", v.to_s)\n        body_params.delete(k)\n      end\n    end\n"
        out += "    query_params = body_params.select { |k, _| #{query_keys.inspect}.include?(k.to_s) }\n"
        out += "    header_params = body_params.select { |k, _| #{header_keys.inspect}.include?(k.to_s) }\n"
        out += "    query_params.keys.each { |k| body_params.delete(k) }\n"
        out += "    header_params.keys.each { |k| body_params.delete(k) }\n"
        out += "    base = @base_url.end_with?('/') ? @base_url[0...-1] : @base_url\n"
        out += "    path_prefix = req_path.start_with?('/') ? req_path : '/' + req_path\n"
        out += "    uri = URI(base + path_prefix)\n"
        if %w[get delete].include?(method)
          out += "    all_query = query_params.merge(body_params)\n"
          out += "    uri.query = URI.encode_www_form(all_query) if !all_query.empty?\n"
        else
          out += "    uri.query = URI.encode_www_form(query_params) if !query_params.empty?\n"
        end
        out += "    req = Net::HTTP::#{method.capitalize}.new(uri.request_uri || uri.path)\n"
        out += "    header_params.each { |k, v| req[k.to_s] = v.to_s }\n"
        if details['security'] && !details['security'].empty?
          out += "    req['api_key'] = @api_key || 'special-key'\n"
          out += "    req['Authorization'] = \"Bearer \#{@access_token || 'mock-token-123'}\"\n"
        end
        out += emit_request_body_handling(method, details, body_key)
        out += '    @last_response = Net::HTTP.start(uri.hostname, uri.port, ' \
               "use_ssl: uri.scheme == 'https') { |http| http.request(req) }\n"
        "#{out}    JSON.parse(@last_response.body) rescue @last_response.body\n  end\n\n"
      end

      # Emits YARD comment lines for a `ClientSdk` operation method.
      #
      # @param path [String] endpoint path
      # @param details [Hash] OpenAPI operation details
      # @return [String] comment lines
      def self.emit_operation_doc_comments(path, details)
        out = ''
        out += "  # #{details['summary']}\n" if details['summary']
        out += "  # @param path [String] #{path}\n"
        details['parameters']&.each do |param|
          out += "  # @param #{param['name']} [#{param['in']}]\n"
          out += "  #  required: #{param['required']}, allowEmptyValue: #{param['allowEmptyValue']}, " \
                 "style: #{param['style']}, explode: #{param['explode']}, allowReserved: #{param['allowReserved']}, " \
                 "schema: #{param.dig('schema', 'type')}\n"
        end
        out += emit_request_body_doc_comments(details['requestBody']) if details['requestBody']
        out + emit_responses_doc_comments(details['responses'])
      end

      # Emits YARD comment lines for an operation's `requestBody`.
      #
      # @param request_body [Hash] OpenAPI requestBody hash
      # @return [String] comment lines
      def self.emit_request_body_doc_comments(request_body)
        req = request_body['required'] ? 'required' : 'optional'
        out = "  # Request Body (#{req}):\n"
        request_body['content']&.each do |mt, mtdetails|
          out += "  #  #{mt} schema: #{mtdetails.dig('schema', '$ref')}\n"
          mtdetails['encoding']&.each do |enc_k, enc_v|
            out += "  #  Encoding #{enc_k}: contentType=#{enc_v['contentType']} style=#{enc_v['style']} " \
                   "explode=#{enc_v['explode']} allowReserved=#{enc_v['allowReserved']}\n"
          end
        end
        out
      end

      # Emits YARD comment lines for an operation's `responses`.
      #
      # @param responses [Hash, nil] OpenAPI responses map
      # @return [String] comment lines
      def self.emit_responses_doc_comments(responses)
        return '' unless responses

        out = ''
        responses.each do |status, resp|
          out += "  # @return [#{status}] #{resp['description']}\n"
          resp['headers']&.each do |hname, hdetails|
            out += "  #   Header #{hname}: required=#{hdetails['required']}, style=#{hdetails['style']}, " \
                   "explode=#{hdetails['explode']}, schema=#{hdetails.dig('schema', 'type')}\n"
          end
          resp['links']&.each do |lname, ldetails|
            out += "  #   Link #{lname}: operationRef=#{ldetails['operationRef']}\n"
          end
        end
        out
      end

      # Partitions operation parameters into query keys, header keys, and body key.
      #
      # @param parameters [Array<Hash>] OpenAPI parameters array
      # @return [Array(Array<String>, Array<String>, String, nil)] `[query_keys, header_keys, body_key]`
      def self.partition_parameter_keys(parameters)
        query_keys = []
        header_keys = []
        body_key = nil
        parameters.each do |param|
          case param['in']
          when 'query' then query_keys << param['name']
          when 'header' then header_keys << param['name']
          when 'body' then body_key = param['name']
          end
        end
        [query_keys, header_keys, body_key]
      end

      # Emits request body serialization lines for `post`, `put`, and `patch` methods.
      #
      # @param method [String] HTTP verb
      # @param details [Hash] OpenAPI operation details
      # @param body_key [String, nil] Swagger 2 body parameter name if present
      # @return [String] Ruby request body assignment lines
      def self.emit_request_body_handling(method, details, body_key)
        content_type = resolve_content_type(details)
        return '' unless %w[post put patch].include?(method)

        ct_lit = Cdd::TokenScanner.single_quote_literal(content_type)
        if ['application/x-www-form-urlencoded', 'multipart/form-data'].include?(content_type)
          "    req.set_form(body_params.map { |k, v| [k, v.to_s] }, #{ct_lit})\n"
        elsif body_key
          bk_lit = Cdd::TokenScanner.single_quote_literal(body_key)
          "    req['Content-Type'] = #{ct_lit}\n    " \
            "b_name = #{bk_lit}\n    " \
            "b_val = body_params[b_name]\n    " \
            "b_json = b_val.is_a?(String) ? b_val : b_val.to_json\n    " \
            "req.body = body_params.key?(b_name) ? b_json : body_params.to_json\n"
        else
          "    req['Content-Type'] = #{ct_lit}\n    req.body = body_params.to_json\n"
        end
      end

      # Resolves the preferred request content type from `consumes` or `requestBody.content`.
      #
      # @param details [Hash] OpenAPI operation details
      # @return [String] resolved content type string
      def self.resolve_content_type(details)
        candidates = if details['consumes'] && !details['consumes'].empty?
                       details['consumes']
                     elsif details.dig('requestBody', 'content')
                       details['requestBody']['content'].keys
                     else
                       ['application/json']
                     end
        return 'application/x-www-form-urlencoded' if candidates.include?('application/x-www-form-urlencoded')
        return 'multipart/form-data' if candidates.include?('multipart/form-data')

        candidates.first
      end

      # Emits external example comments, webhook stubs, and adapter getters on `ClientSdk`.
      #
      # @param openapi [Hash] parsed OpenAPI specification
      # @return [String] closing methods of `ClientSdk`
      def self.emit_examples_and_webhooks(openapi)
        out = "  # Examples (externalValue)\n"
        openapi.dig('components', 'examples')&.each do |ename, edetails|
          out += "  # Example #{ename}: #{edetails['externalValue']}\n" if edetails['externalValue']
        end
        if openapi['webhooks']
          out += "  # Webhooks:\n"
          openapi['webhooks'].each do |wname, methods|
            methods.each_key do |wmethod|
              out += "  # @webhook #{wname} [#{wmethod.upcase}]\n"
              out += "  def handle_webhook_#{wname}(payload)\n    # Implement webhook logic here\n  end\n"
            end
          end
        end
        "#{out}  def mcp\n    @mcp ||= ClientSdkMcpAdapter.new(self)\n  end\n  " \
          "# Identity Provider Helper\n  def auth\n    @auth ||= ClientSdkAuthAdapter.new(self)\n  end\n  " \
          "def workflows\n    @workflows ||= WorkflowsOrchestrator.new('default' => self)\n  end\nend\n\n"
      end

      # Emits the `ClientSdkAuthAdapter` class.
      #
      # @return [String] Ruby source code for `ClientSdkAuthAdapter`
      def self.emit_auth_adapter
        <<~RUBY
          class ClientSdkAuthAdapter
            def initialize(client)
              @client = client
            end
            def register(username, password, overrides = {})
              uri = URI(@client.base_url.gsub(/\\/api\\/v[0-9]+|\\/v[0-9]+/, '') + '/auth/register')
              req = Net::HTTP::Post.new(uri.path)
              req['Content-Type'] = 'application/json'
              req.body = { username: username, password: password }.merge(overrides).to_json
              res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(req) }
              JSON.parse(res.body) rescue res.body
            end
            def login(username, password)
              uri = URI(@client.base_url.gsub(/\\/api\\/v[0-9]+|\\/v[0-9]+/, '') + '/auth/login')
              req = Net::HTTP::Post.new(uri.path)
              req['Content-Type'] = 'application/json'
              req.body = { username: username, password: password }.to_json
              res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(req) }
              data = JSON.parse(res.body) rescue {}
              if data['token']
                @client.access_token = data['token']
                return true
              end
              false
            end
            def logout
              uri = URI(@client.base_url.gsub(/\\/api\\/v[0-9]+|\\/v[0-9]+/, '') + '/auth/logout')
              req = Net::HTTP::Post.new(uri.path)
              Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(req) }
              @client.access_token = nil
            end
          end

        RUBY
      end

      # Emits the `ClientSdkMcpAdapter` class using `ClientSdkCli::Emitter.build_mcp_tools`.
      #
      # @param openapi [Hash] parsed OpenAPI specification
      # @param arazzo [Hash, nil] optional parsed Arazzo specification
      # @return [String] Ruby source code for `ClientSdkMcpAdapter`
      def self.emit_mcp_adapter(openapi, arazzo = nil)
        tools_json = Cdd::ClientSdkCli::Emitter.build_mcp_tools(openapi, arazzo).to_json
        <<~RUBY
          class ClientSdkMcpAdapter
            def initialize(client)
              @client = client
            end
            def get_tools
              #{tools_json}
            end
            def execute_tool(name, args)
              if @client.respond_to?(name)
                @client.send(name, args)
              else
                @client.workflows.send(name, args)
              end
            end
            def get_resources
              [
                { uri: 'mcp://docs/api', name: 'API Documentation', mimeType: 'text/markdown' }
              ]
            end
            def read_resource(uri)
              if uri == 'mcp://docs/api'
                { contents: [{ uri: uri, mimeType: 'text/markdown', text: '# API Docs' }] }
              end
            end
            def get_prompts
              [{ name: 'summarize_api', description: 'Summarize the API wrapper', arguments: [{ name: 'focus', description: 'Focus area', required: false }] }]
            end
            def get_prompt(name, args = {})
              if name == 'summarize_api'
                { description: 'API summary prompt', messages: [{ role: 'user', content: { type: 'text', text: 'Please summarize this API wrapper' } }] }
              end
            end
            def handle_logging_level(level)
              # No-op for generated code
            end
            def handle_ping
              true
            end
            def handle_initialized
              true
            end
            def handle_close
              true
            end
            def handle_cancelled(request_id)
              # No-op for generated code
            end
            def get_roots
              []
            end
            def get_resource_templates
              []
            end
            def sample_message
              { role: 'assistant', model: 'stub-model', stopReason: 'endTurn', content: { type: 'text', text: 'sampled' } }
            end
            def handle_progress(progress_token, progress, total)
              # No-op for generated code
            end
            def handle_subscribe(uri)
              # No-op for generated code
            end
            def handle_unsubscribe(uri)
              # No-op for generated code
            end
            def complete_prompt(prompt_name, arg_name, value)
              { completion: { values: [], total: 0, hasMore: false } }
            end
            alias set_level handle_logging_level
            alias ping handle_ping
            alias initialized handle_initialized
            alias close handle_close
            alias cancelled handle_cancelled
            alias progress handle_progress
            alias subscribe handle_subscribe
            alias unsubscribe handle_unsubscribe
          end
        RUBY
      end
    end
  end
end
