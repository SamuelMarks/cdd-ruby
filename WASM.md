# WASM Support

The `cdd-ruby` project supports WebAssembly (WASM) to enable running the Ruby-based Compiler Driven Development CLI and JSON-RPC server in environments without a Ruby interpreter installed (e.g., within a browser or on another language runtime).

## Building WASM

You can build the WASM module using the `build_wasm` make task:

```bash
make build_wasm
```

On Windows:

```bat
make.bat build_wasm
```

This task uses `rbwasm` (the Ruby WASM packager) to bundle the Ruby interpreter along with the `cdd-ruby` source files into a standalone `.wasm` file.

## Integration

The generated `dist/cdd-ruby.wasm` can be used directly with standard WASM runtimes (like Wasmtime, Wasmer, or Node.js) and can also run in modern web browsers.

This allows seamless integration into the unified CLI of all `cdd-*` projects and the unified web interface.
