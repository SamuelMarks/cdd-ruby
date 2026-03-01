@echo off
setlocal enabledelayedexpansion

if "%~1"=="" goto help
if "%~1"=="help" goto help
if "%~1"=="all" goto help
if "%~1"=="install_base" goto install_base
if "%~1"=="install_deps" goto install_deps
if "%~1"=="build_docs" goto build_docs
if "%~1"=="build" goto build
if "%~1"=="test" goto test
if "%~1"=="run" goto run
if "%~1"=="build_wasm" goto build_wasm

echo Unknown target: %~1
goto help

:help
echo Available tasks:
echo   install_base  : Install language runtime (Ruby using choco)
echo   install_deps  : Install local dependencies (bundle install)
echo   build_docs    : Build the API docs and put them in the 'docs' directory (or positional arg)
echo   build         : Build the CLI binary (or positional arg)
echo   test          : Run tests locally
echo   run           : Run the CLI. Any args after run are given to the CLI.
echo   build_wasm    : Build the WASM version of the CLI
echo   help          : Show this help text
echo   all           : Show this help text
goto :eof

:install_base
echo Installing Ruby via Chocolatey...
choco install ruby -y
goto :eof

:install_deps
bundle install
goto :eof

:build_docs
set DOCS_DIR=%~2
if "%DOCS_DIR%"=="" set DOCS_DIR=docs
bundle exec yard doc -o %DOCS_DIR% "src/**/*.rb"
goto :eof

:build
set BIN_DIR=%~2
if "%BIN_DIR%"=="" set BIN_DIR=bin
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
copy bind-ruby "%BIN_DIR%d-ruby"
echo Built CLI to %BIN_DIR%d-ruby
goto :eof

:test
bundle exec rspec
goto :eof

:run
set BIN_DIR=%~2
if "%BIN_DIR%"=="" set BIN_DIR=bin
if not exist "%BIN_DIR%d-ruby" call :build %BIN_DIR%

:: Shift the first argument (run)
shift
:: Collect all remaining arguments
set "RUN_ARGS="
:collect_args
if "%~1"=="" goto run_cli
set "RUN_ARGS=%RUN_ARGS% %1"
shift
goto collect_args

:run_cli
ruby "%BIN_DIR%d-ruby" %RUN_ARGS%
goto :eof

:build_wasm
echo Building WASM...

curl -L -o ruby.wasm https://github.com/ruby/ruby.wasm/releases/download/2.6.0/ruby-3.2-wasm32-unknown-wasip1-full.wasm
npx --yes wasi-vfs pack ruby.wasm --mapdir /src::./src --mapdir /bin::./bin -o cdd-ruby.wasm
echo cdd-ruby.wasm generated.
goto :eof
