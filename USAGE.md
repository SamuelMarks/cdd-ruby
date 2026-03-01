# Usage Guide

The `cdd-ruby` compiler operates mostly from the CLI:

```bash
# Get help
cdd-ruby -h

# Convert a Ruby file to an OpenAPI Spec
cdd-ruby to_openapi -f app.rb -o spec.json

# Convert an OpenAPI Spec to a client SDK
cdd-ruby from_openapi to_sdk -i spec.json -o ./client_dir

# Generate Docs JSON
cdd-ruby to_docs_json -i spec.json -o docs.json

# Run JSON-RPC Server
cdd-ruby server_json_rpc --port 8080 --listen 0.0.0.0
```
