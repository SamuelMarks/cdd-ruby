# frozen_string_literal: true

require 'json'
require_relative 'cdd'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # The Server class exposes the CDD compiler as a JSON-RPC server.
  class Server
    # Starts the JSON-RPC server.
    # @param listen [String] the host to bind to
    # @param port [Integer, String] the port to listen on
    # @return [void]
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
              res.body = { jsonrpc: '2.0', error: 'Invalid JSON-RPC request', code: -32_600 }.to_json
            end
          rescue Cdd::RpcError => e
            res.status = 500
            res.body = { jsonrpc: '2.0', error: e.message, code: e.code }.to_json
          rescue StandardError => e
            res.status = 500
            res.body = { jsonrpc: '2.0', error: e.message, code: -32_700 }.to_json
          end
        else
          res.status = 405
        end
      end

      trap('INT') { server.shutdown }
      puts "JSON-RPC server listening on #{listen}:#{port}"
      server.start
    end

    # Handles an incoming JSON-RPC method.
    # @param method [String] the RPC method name
    # @param params [Hash] the RPC parameters
    # @return [Object] the result of the RPC call
    # @raise [Cdd::RpcError] when the RPC method is not found
    def self.handle_rpc(method, params)
      case method
      when 'version'
        '0.0.4'
      when 'to_openapi'
        filepath = params['input']
        Cdd::Parser.parse(filepath)
      when 'to_arazzo'
        filepath = params['input']
        Cdd::Parser.parse_to_arazzo(filepath)
      when 'to_docs_json'
        input = params['input']
        no_imports = params['no_imports'] || false
        no_wrapping = params['no_wrapping'] || false
        Cdd::DocsJson::Emitter.emit(input, no_imports: no_imports, no_wrapping: no_wrapping)
      when 'from_openapi_to_sdk_cli', 'from_arazzo_to_sdk_cli'
        Cdd::Emitter.emit_sdk_cli(params.transform_keys(&:to_sym))
      when 'from_openapi_to_sdk', 'from_arazzo_to_sdk'
        Cdd::Emitter.emit_sdk(params.transform_keys(&:to_sym))
      when 'from_openapi_to_server', 'from_arazzo_to_server'
        Cdd::Emitter.emit_server(params.transform_keys(&:to_sym))
      else
        raise Cdd::RpcError.new("Method not found: #{method}", code: -32_601)
      end
    end
  end
end
