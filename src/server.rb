# frozen_string_literal: true

require 'json'
require_relative 'cdd'

module Cdd
  # The Server class exposes the CDD compiler as a JSON-RPC server.
  class Server
    # Starts the JSON-RPC server.
    # @param listen [String] the host to bind to
    # @param port [Integer, String] the port to listen on
    def self.start(listen, port)
      require 'webrick'
      server = WEBrick::HTTPServer.new(Port: port.to_i, BindAddress: listen)

      server.mount_proc '/' do |req, res|
        if req.request_method == 'POST'
          begin
            body = JSON.parse(req.body)
            if body['jsonrpc'] == '2.0'
              method = body['method']
              params = body['params'] || {}
              id = body['id']

              result = handle_rpc(method, params)

              res.body = { jsonrpc: '2.0', result: result, id: id }.to_json
              res.content_type = 'application/json'
            else
              res.status = 400
              res.body = { error: 'Invalid JSON-RPC request' }.to_json
            end
          rescue StandardError => e
            res.status = 500
            res.body = { error: e.message }.to_json
          end
        else
          res.status = 405
        end
      end

      trap 'INT' do server.shutdown end
      puts "JSON-RPC server listening on #{listen}:#{port}"
      server.start
    end

    # Handles an incoming JSON-RPC method.
    # @param method [String] the RPC method name
    # @param params [Hash] the RPC parameters
    # @return [Object] the result of the RPC call
    def self.handle_rpc(method, params)
      case method
      when 'version'
        '0.0.1'
      when 'to_openapi'
        filepath = params['f'] || params['filepath']
        Cdd::Parser.parse(filepath)
      when 'to_docs_json'
        input = params['i'] || params['input']
        no_imports = params['no_imports'] || false
        no_wrapping = params['no_wrapping'] || false
        Cdd::DocsJson::Emitter.emit(input, no_imports: no_imports, no_wrapping: no_wrapping)
      when 'from_openapi_to_sdk_cli'
        Cdd::Emitter.emit_sdk_cli(params.transform_keys(&:to_sym))
      when 'from_openapi_to_sdk'
        params['i'] || params['input']
        params['input_dir']
        Cdd::Emitter.emit_sdk(params.transform_keys(&:to_sym))
      when 'from_openapi_to_server'
        Cdd::Emitter.emit_server(params.transform_keys(&:to_sym))
      else
        raise "Method not found: #{method}"
      end
    end
  end
end
