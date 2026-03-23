@echo off
setlocal enabledelayedexpansion

if "%1"=="" goto help
if "%1"=="help" goto help
if "%1"=="all" goto help
if "%1"=="install_base" goto install_base
if "%1"=="install_deps" goto install_deps
if "%1"=="build_docs" goto build_docs
if "%1"=="build" goto build
if "%1"=="test" goto test
if "%1"=="run" goto run
if "%1"=="build_wasm" goto build_wasm
if "%1"=="build_docker" goto build_docker
if "%1"=="run_docker" goto run_docker

echo Unknown command: %1
goto help

:help
echo Available tasks:
echo   install_base   Install language runtime and relevant tools
echo   install_deps   Install local dependencies
echo   build_docs     Build the API docs and put them in the docs directory. Alternative: set DOCS_DIR=docs ^& make build_docs
echo   build          Build the CLI binary. Alternative: set BIN_DIR=bin ^& make build
echo   test           Run tests locally
echo   run            Run the CLI. Usage: make run ARGS="--version"
echo   build_wasm     Build the WASM binary
echo   build_docker   Build the Docker images
echo   run_docker     Run the Docker container
echo   help           Show what options are available
echo   all            Show help text
goto :eof

:install_base
echo Please ensure Ruby ^>= 3.4.0 is installed.
gem install bundler
call gem install ruby_wasm
goto :eof

:install_deps
bundle install
goto :eof

:build_docs
if "%DOCS_DIR%"=="" set DOCS_DIR=docs
bundle exec yard doc --output-dir %DOCS_DIR%
goto :eof

:build
if "%BIN_DIR%"=="" set BIN_DIR=bin
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
gem build cdd-ruby.gemspec
move cdd-ruby-0.0.1.gem "%BIN_DIR%\" >nul 2>&1
goto :eof

:test
bundle exec rspec
goto :eof

:run
call :build
if "%BIN_DIR%"=="" set BIN_DIR=bin
bundle exec ruby bin/cdd-ruby %ARGS%
goto :eof
:build_wasm
if not defined BIN_DIR set BIN_DIR=dist
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
echo Building WASM via ruby-wasm. It requires ruby.wasm packager.
rbwasm build -o "%BIN_DIR%\ruby.wasm" --disable-gems
rbwasm pack "%BIN_DIR%\ruby.wasm" --dir src::/src --dir bin::/bin -o "%BIN_DIR%\cdd-ruby.wasm"
exit /b 0
goto :eof

:build_docker
docker build -f alpine.Dockerfile -t cdd-ruby:alpine .
docker build -f debian.Dockerfile -t cdd-ruby:debian .
goto :eof

:run_docker
call :build_docker
echo Running alpine image:
docker run --rm -d -p 8082:8082 --name cdd_alpine cdd-ruby:alpine
timeout /t 2 >nul
curl -s -X POST -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"version\",\"params\":{},\"id\":1}" http://localhost:8082
docker stop cdd_alpine >nul 2>&1
echo Running debian image:
docker run --rm -d -p 8083:8082 --name cdd_debian cdd-ruby:debian
timeout /t 2 >nul
curl -s -X POST -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"version\",\"params\":{},\"id\":1}" http://localhost:8083
docker stop cdd_debian >nul 2>&1
    docker rmi cdd-ruby:alpine cdd-ruby:debian >nul 2>&1
goto :eof
