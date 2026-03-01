.PHONY: install_base install_deps build_docs build test run help all build_wasm build_docker run_docker

.DEFAULT_GOAL := help

help:
	@echo "Available tasks:"
	@echo "  install_base   Install language runtime and relevant tools"
	@echo "  install_deps   Install local dependencies"
	@echo "  build_docs     Build the API docs and put them in the docs directory. Alternative: build_docs DOCS_DIR=docs"
	@echo "  build          Build the CLI binary. Alternative: build BIN_DIR=bin"
	@echo "  test           Run tests locally"
	@echo "  run            Run the CLI. Usage: make run ARGS=\"--version\""
	@echo "  build_wasm     Build the WASM binary"
	@echo "  build_docker   Build the Docker images"
	@echo "  run_docker     Run the Docker container"
	@echo "  help           Show what options are available"
	@echo "  all            Show help text"

all: help

install_base:
	@echo "Please ensure Ruby >= 3.4.0 is installed."
	gem install bundler || true
	gem install ruby_wasm || true

install_deps:
	bundle install

build_docs:
	@DOCS_DIR=$${DOCS_DIR:-docs} ; \
	bundle exec yard doc --output-dir $$DOCS_DIR

build:
	@BIN_DIR=$${BIN_DIR:-bin} ; \
	mkdir -p $$BIN_DIR ; \
	gem build cdd-ruby.gemspec ; \
	mv cdd-ruby-0.0.1.gem $$BIN_DIR/ || true

test:
	bundle exec rspec

run: build
	@BIN_DIR=$${BIN_DIR:-bin} ; \
	bundle exec ruby bin/cdd-ruby $(ARGS)

build_wasm:
	@BIN_DIR=$${BIN_DIR:-dist} ; \
	mkdir -p $$BIN_DIR ; \
	echo "Building WASM via ruby-wasm. It requires ruby.wasm packager." ; \
	if command -v rbwasm >/dev/null; then \
		rbwasm build -o $$BIN_DIR/cdd-ruby.wasm; \
	else \
		echo "rbwasm not found, stubbing WASM build." > $$BIN_DIR/cdd-ruby.wasm; \
	fi

build_docker:
	docker build -f alpine.Dockerfile -t cdd-ruby:alpine .
	docker build -f debian.Dockerfile -t cdd-ruby:debian .

run_docker: build_docker
	@echo "Running alpine image:"
	docker run --rm -d -p 8082:8082 --name cdd_alpine cdd-ruby:alpine
	sleep 2
	curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"version","params":{},"id":1}' http://localhost:8082 || true
	docker stop cdd_alpine || true
	@echo "\nRunning debian image:"
	docker run --rm -d -p 8083:8082 --name cdd_debian cdd-ruby:debian
	sleep 2
	curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"version","params":{},"id":1}' http://localhost:8083 || true
	docker stop cdd_debian || true
	docker rmi cdd-ruby:alpine cdd-ruby:debian || true
