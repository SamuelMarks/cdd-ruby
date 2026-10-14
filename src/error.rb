# frozen_string_literal: true

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Base error class for all CDD domain errors.
  class Error < StandardError; end

  # Raised when parsing Ruby source code or OpenAPI specifications fails.
  class ParseError < Error; end

  # Raised when emitting Ruby code or OpenAPI artifacts fails.
  class EmitError < Error; end

  # Raised when configuration or schema validation fails.
  class ValidationError < Error; end

  # Raised when a JSON-RPC request or method invocation fails.
  class RpcError < Error
    # The JSON-RPC 2.0 numeric error code.
    # @return [Integer]
    attr_reader :code

    # Initializes a new JSON-RPC error with a message and code.
    #
    # @param message [String] human-readable error message
    # @param code [Integer] JSON-RPC 2.0 error code (default: -32601)
    # @return [Cdd::RpcError]
    def initialize(message, code: -32_601)
      super(message)
      @code = code
    end
  end

  # Raised when a Model Context Protocol (MCP) tool or resource invocation fails.
  class McpError < Error; end

  # Raised when an operation is attempted in an unsupported runtime environment (e.g., WASM without sockets).
  class UnsupportedEnvironmentError < Error; end
end
