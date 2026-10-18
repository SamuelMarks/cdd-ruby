# Usage Guide

The `cdd-ruby` compiler operates mostly from the CLI:

```bash
# Get help
cdd-ruby -h

# Convert a Ruby file to an OpenAPI Spec
cdd-ruby to_openapi -i app.rb -o spec.json

# Convert an OpenAPI Spec to a client SDK
cdd-ruby from_openapi to_sdk -i spec.json -o ./client_dir

# Convert an Arazzo 1.1.0 Spec to a client SDK, CLI, or Server
cdd-ruby from_arazzo to_sdk -i arazzo.json -o ./client_dir
cdd-ruby from_arazzo to_sdk_cli -i arazzo.json -o ./cli_dir
cdd-ruby from_arazzo to_server -i arazzo.json -o ./server_dir

# Convert Ruby workflow code to an Arazzo 1.1.0 Spec
cdd-ruby to_arazzo -i workflows.rb -o arazzo.json

# Generate Docs JSON
cdd-ruby to_docs_json -i spec.json -o docs.json

# Run JSON-RPC Server
cdd-ruby serve_json_rpc -p 8080 -l 0.0.0.0
```
