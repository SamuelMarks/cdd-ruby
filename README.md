cdd-ruby
============

[![License](https://img.shields.io/badge/license-Apache--2.0%20OR%20MIT-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![CI](https://github.com/SamuelMarks/cdd-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/SamuelMarks/cdd-ruby/actions/workflows/ci.yml)
[![Test Coverage](https://img.shields.io/badge/coverage-100.0%25-brightgreen.svg)]()
[![Doc Coverage](https://img.shields.io/badge/docs-100.0%25-brightgreen.svg)]()

OpenAPI ↔ Ruby. This is one compiler in a suite, all focussed on the same task: Compiler Driven Development (CDD).

Each compiler is written in its target language, is whitespace and comment sensitive, and has both an SDK and CLI.

The CLI—at a minimum—has:
- `cdd-ruby --help`
- `cdd-ruby --version`
- `cdd-ruby from_openapi -i spec.json`
- `cdd-ruby to_openapi -f path/to/code`
- `cdd-ruby to_docs_json --no-imports --no-wrapping -i spec.json`

The goal of this project is to enable rapid application development without tradeoffs. Tradeoffs of Protocol Buffers / Thrift etc. are an untouchable "generated" directory and package, compile-time and/or runtime overhead. Tradeoffs of Java or JavaScript for everything are: overhead in hardware access, offline mode, ML inefficiency, and more. And neither of these alterantive approaches are truly integrated into your target system, test frameworks, and bigger abstractions you build in your app. Tradeoffs in CDD are code duplication (but CDD handles the synchronisation for you).

## 🚀 Capabilities

The `cdd-ruby` compiler leverages a unified architecture to support various facets of API and code lifecycle management.

* **Compilation**:
  * **OpenAPI → `Ruby`**: Generate idiomatic native models, network routes, client SDKs, database schemas, and boilerplate directly from OpenAPI (`.json` / `.yaml`) specifications.
  * **`Ruby` → OpenAPI**: Statically parse existing `Ruby` source code and emit compliant OpenAPI specifications.
* **AST-Driven & Safe**: Employs static analysis (Abstract Syntax Trees) instead of unsafe dynamic execution or reflection, allowing it to safely parse and emit code even for incomplete or un-compilable project states.
* **WebAssembly Ready**: The compiler supports compilation to WebAssembly, enabling `cdd-ruby` to run directly in the browser or specialized WASM environments.
* **Seamless Sync**: Keep your docs, tests, database, clients, and routing in perfect harmony. Update your code, and generate the docs; or update the docs, and generate the code.

## 📦 Installation

Requires Ruby 3.0+. Add `gem "cdd-ruby"` to your Gemfile or run `gem install cdd-ruby`

## 🛠 Usage

### Command Line Interface

<!-- INSTRUCTION TO LLM: Provide 1-2 idiomatic CLI examples using the `cdd-ruby` placeholder. Ensure paths reflect standard `Ruby` project structures. -->

### Programmatic SDK / Library

<!-- INSTRUCTION TO LLM: Provide a small code snippet in `Ruby` demonstrating how to invoke the compiler as a library, using the `rb`. -->

## Design choices

The Ruby implementation leverages the built-in `Ripper` standard library to statically analyze Ruby syntax trees without requiring execution. This ensures safe and fast AST parsing. It specifically targets emitting pure Ruby without excessive dependencies (like `net/http` for clients) to maximize interoperability in diverse Ruby and Rails environments.

## 🏗 Supported Conversions for Ruby

*(The boxes below reflect the features supported by this specific `cdd-ruby` implementation)*

| Concept | Parse (From) | Emit (To) |
|---------|--------------|-----------|
| OpenAPI (JSON/YAML) | ✅ | ✅ |
| `Ruby` Models / Structs / Types | ✅ | ✅ |
| `Ruby` Server Routes / Endpoints | ✅ | ✅ |
| `Ruby` API Clients / SDKs | ✅ | ✅ |
| `Ruby` ORM / DB Schemas | ✅ | ✅ |
| `Ruby` CLI Argument Parsers | ✅ | ✅ |
| WebAssembly (WASM) Compilation | ✅ | ✅ |
| `Ruby` Docstrings / Comments | ✅ | ✅ |



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
