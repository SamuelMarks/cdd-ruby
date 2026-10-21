# frozen_string_literal: true

require 'json'
require_relative 'cdd'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # The Server class exposes the CDD compiler as a JSON-RPC server.
  class Server
    class << self
      # @return [WEBrick::HTTPServer, nil] the currently active WEBrick server instance
      attr_reader :current_server
    end

    # Builds and configures a `WEBrick::HTTPServer` mounted with the CDD JSON-RPC handler.
    #
    # @param listen [String] the host to bind to
    # @param port [Integer, String] the port to listen on
    # @return [WEBrick::HTTPServer] configured HTTP server instance
    def self.build(listen, port)
      require 'webrick'
      server = WEBrick::HTTPServer.new(Port: port.to_i, BindAddress: listen, AccessLog: [],
                                       Logger: WEBrick::Log.new(File::NULL))

      server.mount_proc '/' do |req, res|
        handle_http_request(req, res)
      end
      @current_server = server
    end

    # Shuts down the currently active WEBrick server if running.
    #
    # @return [void]
    def self.shutdown
      @current_server&.shutdown
    end

    # Handles an incoming WEBrick HTTP request and populates the HTTP response.
    #
    # @param req [WEBrick::HTTPRequest] incoming HTTP request
    # @param res [WEBrick::HTTPResponse] outgoing HTTP response
    # @return [void]
    def self.handle_http_request(req, res)
      if req.request_method == 'POST'
        begin
          body = JSON.parse(req.body)
          if body['jsonrpc'] == '2.0'
            result = handle_rpc(body['method'], body['params'] || {})
            res.body = { jsonrpc: '2.0', result: result, id: body['id'] }.to_json
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

    # Starts the JSON-RPC server.
    # @param listen [String] the host to bind to
    # @param port [Integer, String] the port to listen on
    # @return [void]
    def self.start(listen, port)
      server = build(listen, port)
      trap('INT') { server.shutdown }
      puts "JSON-RPC server listening on #{listen}:#{port}"
      server.start
    end

    # Mapping of emitter RPC method names to `Cdd::Emitter` class methods.
    EMITTER_RPC_METHODS = {
      'from_openapi_to_sdk_cli' => :emit_sdk_cli,
      'from_arazzo_to_sdk_cli' => :emit_sdk_cli,
      'from_openapi_to_sdk' => :emit_sdk,
      'from_arazzo_to_sdk' => :emit_sdk,
      'from_openapi_to_server' => :emit_server,
      'from_arazzo_to_server' => :emit_server
    }.freeze

    # Handles an incoming JSON-RPC method.
    # @param method [String] the RPC method name
    # @param params [Hash] the RPC parameters
    # @return [Object] the result of the RPC call
    # @raise [Cdd::RpcError] when the RPC method is not found
    def self.handle_rpc(method, params)
      if EMITTER_RPC_METHODS.key?(method)
        return Cdd::Emitter.public_send(EMITTER_RPC_METHODS[method], params.transform_keys(&:to_sym))
      end

      case method
      when 'version' then Cdd::VERSION
      when 'to_openapi' then Cdd::Parser.parse(params['input'])
      when 'to_arazzo' then Cdd::Parser.parse_to_arazzo(params['input'])
      when 'to_docs_json'
        Cdd::DocsJson::Emitter.emit(
          params['input'],
          no_imports: params['no_imports'] || false,
          no_wrapping: params['no_wrapping'] || false
        )
      else
        raise Cdd::RpcError.new("Method not found: #{method}", code: -32_601)
      end
    end
  end
end
