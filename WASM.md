# WebAssembly (WASM) Support

The `cdd-ruby` compiler supports being compiled to WASM. This allows the CLI to run natively in a web browser or a WASM runtime like Wasmtime.

## Building WASM

Run:

```bash
make build_wasm
```

This will download `ruby.wasm` and package the application logic inside a WASI filesystem to produce `cdd-ruby.wasm`.
