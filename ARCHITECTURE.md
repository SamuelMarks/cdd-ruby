# cdd-ruby Architecture

<!-- COVERAGE_BADGES_START -->
[![Test Coverage](https://img.shields.io/badge/coverage-100.00%25-brightgreen.svg)]()
[![Doc Coverage](https://img.shields.io/badge/docs-100.00%25-brightgreen.svg)]()
<!-- COVERAGE_BADGES_END -->

The `cdd-ruby` framework implements a **Compiler Driven Development (CDD)** workflow in Ruby, centered around an **Intermediate Representation (IR)** (`Cdd::IR`) that connects OpenAPI 3.2.0, Arazzo 1.1.0, and idiomatic Ruby source code.

## High-Level Data Flow

```text
[Ruby Source Code] <===(Parse / Emit)===> [Intermediate Representation (Cdd::IR)] <===(Parse / Emit)===> [OpenAPI 3.2.0 / Arazzo 1.1.0]
```

## Directory Structure

All compiler components live under `src/` with symmetric `parse.rb` and `emit.rb` pairs:

- `src/cdd.rb`: Core entry point (`Cdd::Parser`, `Cdd::Emitter`, `Cdd::McpServer`).
- `src/cli.rb`: CLI argument parser (`Cdd::CLI`, `Cdd::Config`) and MCP stdio server dispatcher.
- `src/ir.rb`: Strongly-typed `Data.define` Intermediate Representation (`Cdd::IR`) for OpenAPI 3.2.0 and Arazzo 1.1.0 models.
- `src/error.rb`: Domain error hierarchy (`Cdd::Error`, `Cdd::ParseError`, `Cdd::EmitError`, `Cdd::ValidationError`, `Cdd::ArazzoValidationError`, `Cdd::RuntimeExpressionError`, `Cdd::RpcError`, `Cdd::McpError`, `Cdd::UnsupportedEnvironmentError`).
- `src/token_scanner.rb`: Shared `Ripper.lex` token scanning utilities (`Cdd::TokenScanner`).
- `src/server.rb`: JSON-RPC 2.0 server (`Cdd::Server`) over WEBrick HTTP or WASI stdio.
- `src/sync.rb`: In-place specification synchronizer (`Cdd::Sync`).
- `src/scaffolding.rb`: Project packaging, Gemspec, Gemfile, and GitHub Actions generator (`Cdd::Scaffolding`).
- `src/arazzo/`: Arazzo 1.1.0 workflow parser, `WorkflowsOrchestrator` emitter, and runtime expression/criterion/selector/replacement evaluators (`runtime_expression.rb`).
- `src/classes/`: Data models and OpenAPI component schema transformations.
- `src/client_sdk/`: `Net::HTTP` `ClientSdk` and `ClientSdkMcpAdapter` generator and parser.
- `src/client_sdk_cli/`: `OptionParser` `sdk_cli.rb` CLI generator and parser.
- `src/docs_json/`: Runnable SDK snippet generator (`to_docs_json`) and parser.
- `src/docstrings/`: YARD and `@route` / `@schema` / `@param` / `@response` docstring parser and emitter.
- `src/functions/`: `ApiClient` function parser and emitter.
- `src/mocks/`: `@mock` and `@example_external` parser and emitter.
- `src/openapi/`: Top-level `@api_*` OpenAPI metadata parser and emitter.
- `src/routes/`: Sinatra route block and component docstring parser and emitter.
- `src/server/`: Sinatra server, ActiveRecord DAO, Faker seeder, and middleware generator and parser.
- `src/tests/`: Minitest unit/integration and E2E workflow test generator and parser.

## Core Principles

1. **Static Analysis Only**: No dynamic `eval` or `ObjectSpace` execution of untrusted target source files; all Ruby parsing is performed via `Ripper.lex` token streams.
2. **Bidirectional Preservation**: Round-tripping preserves schemas, routes, parameters, security schemes, callbacks, webhooks, links, and Arazzo 1.1.0 workflows across `Source -> IR -> Target`.
3. **Symmetric Operations**: Every endpoint and workflow in `Cdd::IR` holds all metadata required to emit server routes, client SDK methods, CLI commands, and Minitest assertions.
