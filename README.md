cdd-ruby
============

[![License](https://img.shields.io/badge/license-Apache--2.0%20OR%20MIT-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![CI/CD](https://github.com/offscale/cdd-ruby/workflows/CI/badge.svg)](https://github.com/offscale/cdd-ruby/actions)
<!-- COVERAGE_BADGES_START -->
[![Test Coverage](https://img.shields.io/badge/coverage-100.0%25-brightgreen.svg)]()
[![Doc Coverage](https://img.shields.io/badge/docs-100.0%25-brightgreen.svg)]()
<!-- COVERAGE_BADGES_END -->

OpenAPI ↔ Ruby. This is one compiler in a suite, all focussed on the same task: Compiler Driven Development (CDD).

Each compiler is written in its target language, is whitespace and comment sensitive, and has both an SDK and CLI.

The CLI—at a minimum—has:
- `cdd-ruby --help`
- `cdd-ruby --version`
- `cdd-ruby from_openapi to_sdk_cli -i spec.json`
- `cdd-ruby to_openapi -f path/to/code`
- `cdd-ruby to_docs_json --no-imports --no-wrapping -i spec.json`

The goal of this project is to enable rapid application development without tradeoffs. Tradeoffs of Protocol Buffers / Thrift etc. are an untouchable "generated" directory and package, compile-time and/or runtime overhead. Tradeoffs of Java or JavaScript for everything are: overhead in hardware access, offline mode, ML inefficiency, and more. And neither of these alterantive approaches are truly integrated into your target system, test frameworks, and bigger abstractions you build in your app. Tradeoffs in CDD are code duplication (but CDD handles the synchronisation for you).

## 🚀 Capabilities

The `cdd-ruby` compiler leverages a unified architecture to support various facets of API and code lifecycle management.

* **Compilation**:
  * **OpenAPI → `Ruby`**: Generate idiomatic native models, network routes, client SDKs, database schemas, and boilerplate directly from OpenAPI (`.json` / `.yaml`) specifications.
  * **`Ruby` → OpenAPI**: Statically parse existing `Ruby` source code and emit compliant OpenAPI specifications.
* **AST-Driven & Safe**: Employs static analysis (Abstract Syntax Trees) instead of unsafe dynamic execution or reflection, allowing it to safely parse and emit code even for incomplete or un-compilable project states.
* **Seamless Sync**: Keep your docs, tests, database, clients, and routing in perfect harmony. Update your code, and generate the docs; or update the docs, and generate the code.

## 📦 Installation

To install `cdd-ruby`, you need Ruby 3.4+ installed. Simply install the gem:

```bash
gem install cdd-ruby
```

## 🛠 Usage

### Command Line Interface

```bash
Usage: cdd-ruby [command] [options]
Commands:
  to_openapi -f <path/to/code> [-o <spec.json>]
  to_docs_json -i <spec.json> [-o <docs.json>] [--no-imports] [--no-wrapping]
  from_openapi to_sdk_cli -i <spec.json> | --input-dir <dir> [-o <target_dir>] [--no-github-actions] [--no-installable-package]
  from_openapi to_sdk -i <spec.json> | --input-dir <dir> [-o <target_dir>] [--no-github-actions] [--no-installable-package]
  from_openapi to_server -i <spec.json> | --input-dir <dir> [-o <target_dir>] [--no-github-actions] [--no-installable-package]
  serve_json_rpc --port <port> --listen <host>
  --help
  --version
```

### Programmatic SDK / Library

```ruby
require 'cdd-ruby'

# Parse Ruby into IR and emit OpenAPI
openapi_json = Cdd::Parser.parse('my_server.rb')

# Parse OpenAPI into IR and emit Ruby Client Code
ruby_code = Cdd::Emitter.emit('spec.json')
```

## Design choices

`cdd-ruby` leverages Ruby's built-in `Ripper` class to build the AST. This completely avoids executing the ruby code and allows parsing partial or incomplete code accurately. We chose `Ripper` instead of `parser` or `ruby_parser` gems to eliminate external dependencies and ensure fast, standard-library-only behavior, while guaranteeing forward compatibility with newer Ruby syntax out of the box. The bidirectional syncing works entirely within the AST representation, making it highly robust.

## 🏗 Supported Conversions for Ruby

*(The boxes below reflect the features supported by this specific `cdd-ruby` implementation)*

| Concept | Parse (From) | Emit (To) |
|---------|--------------|-----------|
| OpenAPI (JSON/YAML) | [x] | [x] |
| `Ruby` Models / Structs / Types | [x] | [x] |
| `Ruby` Server Routes / Endpoints | [x] | [x] |
| `Ruby` API Clients / SDKs | [x] | [x] |
| `Ruby` ORM / DB Schemas | [x] | [x] |
| `Ruby` CLI Argument Parsers | [x] | [x] |
| `Ruby` Docstrings / Comments | [x] | [x] |

---

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or <https://www.apache.org/licenses/LICENSE-2.0>)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or <https://opensource.org/licenses/MIT>)

at your option.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall be
dual licensed as above, without any additional terms or conditions.
## WASM Support

| Feature | Possible | Implemented |
|---------|----------|-------------|
| WASM build | Yes | Yes |
| Run in Browser | Yes | Yes |
| Run via unified CLI | Yes | Yes |

Ruby supports compiling to WebAssembly via the `ruby.wasm` project. This allows running the `cdd-ruby` gem within a JS engine or WASI runtime.
