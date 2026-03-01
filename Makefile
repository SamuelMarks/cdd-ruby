.PHONY: install_base install_deps build_docs build test run help all build_wasm

.DEFAULT_GOAL := help

ifeq (build,$(firstword $(MAKECMDGOALS)))
  BUILD_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(BUILD_ARGS):;@:)
endif

ifeq (build_docs,$(firstword $(MAKECMDGOALS)))
  DOCS_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(DOCS_ARGS):;@:)
endif

ifeq (run,$(firstword $(MAKECMDGOALS)))
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(RUN_ARGS):;@:)
endif

BIN_DIR := $(if $(BUILD_ARGS),$(firstword $(BUILD_ARGS)),bin)
DOCS_DIR := $(if $(DOCS_ARGS),$(firstword $(DOCS_ARGS)),docs)

all: help

help:
	@echo "Available tasks:"
	@echo "  install_base  : Install language runtime (Ruby, gcc, make)"
	@echo "  install_deps  : Install local dependencies (bundle install)"
	@echo "  build_docs    : Build the API docs and put them in the 'docs' directory (or positional arg)"
	@echo "  build         : Build the CLI binary (or positional arg)"
	@echo "  test          : Run tests locally"
	@echo "  run           : Run the CLI. Any args after run are given to the CLI."
	@echo "  build_wasm    : Build the WASM version of the CLI"
	@echo "  help          : Show this help text"
	@echo "  all           : Show this help text"

install_base:
	@echo "Installing Ruby and build dependencies..."
	@if [ "$$(uname)" = "Darwin" ]; then brew install ruby gcc pkg-config; 	elif [ -f /etc/debian_version ]; then sudo apt-get update && sudo apt-get install -y ruby-full ruby-dev build-essential pkg-config; 	elif [ -f /etc/redhat-release ]; then sudo yum install -y ruby ruby-devel gcc make pkgconfig; 	else echo "Unsupported OS for install_base"; exit 1; fi

install_deps:
	bundle install

build_docs:
	bundle exec yard doc -o $(DOCS_DIR) "src/**/*.rb"

build:
	@mkdir -p $(BIN_DIR)
	@if [ "bin/cdd-ruby" != "$(BIN_DIR)/cdd-ruby" ]; then cp bin/cdd-ruby $(BIN_DIR)/cdd-ruby; fi
	@chmod +x $(BIN_DIR)/cdd-ruby
	@echo "Built CLI to $(BIN_DIR)/cdd-ruby"

test:
	bundle exec rspec

run: build
	$(BIN_DIR)/cdd-ruby $(RUN_ARGS)

build_wasm:
	@echo "Building WASM using emsdk (../emsdk) and ruby.wasm approach..."
	
	curl -L -o ruby.tar.gz https://github.com/ruby/ruby.wasm/releases/download/2.8.1/ruby-3.4-wasm32-unknown-wasip1-full.tar.gz
	tar -xzf ruby.tar.gz ruby-3.4-wasm32-unknown-wasip1-full/usr/local/bin/ruby
	mv ruby-3.4-wasm32-unknown-wasip1-full/usr/local/bin/ruby ruby.wasm
	rm -rf ruby-3.4-wasm32-unknown-wasip1-full ruby.tar.gz
	npx --yes wasi-vfs pack ruby.wasm --mapdir /src::./src --mapdir /bin::./bin -o cdd-ruby.wasm
	@echo "cdd-ruby.wasm generated."
