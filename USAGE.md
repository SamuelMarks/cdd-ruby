# Usage Guide

The `cdd-ruby` compiler operates both from the CLI and as a programmatic Ruby library:

```bash
# Get help
cdd-ruby --help

# Convert a Ruby file or directory to an OpenAPI 3.2.0 Spec
cdd-ruby to_openapi -i app.rb -o spec.json

# Convert an OpenAPI Spec to a client SDK
cdd-ruby from_openapi to_sdk -i spec.json -o out_sdk --tests --mcp

# Convert an OpenAPI Spec to a client SDK CLI
cdd-ruby from_openapi to_sdk_cli -i spec.json -o out_cli --tests --mcp

# Convert an OpenAPI Spec to a Sinatra server (with optional ephemeral DB & seed data)
cdd-ruby from_openapi to_server -i spec.json -o out_server --tests --mcp --with-ephemeral --with-seed

# Convert an Arazzo 1.1.0 Spec to a client SDK / CLI / server
cdd-ruby from_arazzo to_sdk -i arazzo.json -o out_arazzo_sdk
cdd-ruby from_arazzo to_sdk_cli -i arazzo.json -o out_arazzo_cli
cdd-ruby from_arazzo to_server -i arazzo.json -o out_arazzo_server

# Convert Ruby workflow code to an Arazzo 1.1.0 Spec
cdd-ruby to_arazzo -i workflows.rb -o arazzo.json

# Synchronize an existing OpenAPI or Arazzo Spec in-place from sibling Ruby files
cdd-ruby sync -i spec.json --truth class

# Generate Docs JSON with runnable Ruby code snippets
cdd-ruby to_docs_json -i spec.json -o docs.json

# Run JSON-RPC 2.0 Server
cdd-ruby serve_json_rpc -p 8080 -l 127.0.0.2

# Run Model Context Protocol (MCP) Server over stdio
cdd-ruby mcp
```
