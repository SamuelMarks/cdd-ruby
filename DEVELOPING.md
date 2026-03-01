# Developing `cdd-ruby`

## Setup
Ensure you have Ruby >= 3.4.0 installed.
Run `make install_base` to get bundler and ruby.wasm packagers.
Run `make install_deps` to install dependencies.

## Testing
Run `make test` locally to ensure 100% test coverage.

## Documentation
Run `make build_docs` to output YARD documentation to `docs` dir.

## Architecture
See `ARCHITECTURE.md` for our overarching goals using Ripper and AST representations for Compiler Driven Development (CDD).
