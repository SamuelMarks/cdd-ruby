# Developing `cdd-ruby`

## Setup
Ensure you have Ruby >= 3.4.0 installed.
Run `make install_base` to get bundler and ruby.wasm packagers.
Run `make install_deps` to install dependencies.

## Testing
Run `make test` locally to run the Minitest suite and RuboCop linter with 100% test coverage.

## Documentation
Run `make docs` (or `make build_docs`) to output YARD documentation to the `doc/` directory with 100% documentation coverage.

## Architecture
See `ARCHITECTURE.md` for our overarching goals using `Ripper.lex` and `Cdd::IR` representations for Compiler Driven Development (CDD).
