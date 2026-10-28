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

This task uses `rbwasm` (the Ruby WASM packager) to bundle the Ruby interpreter along with the `cdd-ruby` source files into a standalone `.wasm` file, followed by an automated size-reduction pipeline in `scripts/build_wasm.py`:

1. **WASI `/usr` VFS Pruning (~36 MB saved)**: Excludes `libruby-static.a` (~21.9 MB), C headers (~1.5 MB), manpages, cached `.gem` archives, and unused stdlib development libraries (`rdoc`, `irb`, `bundler`, `rubygems`, `prism`, `reline`, `unicode_normalize`), keeping only the stdlib files required at runtime (`~650 KB`) plus lightweight `gem_prelude` stubs.
2. **Custom & DWARF Debug Section Stripping (~17.8 MB saved)**: Strips `.debug_*`, `name`, and `producers` custom WASM sections (`sec_id == 0`).
3. **Unused C Extension & Transcoding Table Pruning (~7.3 MB saved)**: Stubs unreachable C extension functions (`openssl`/`libcrypto`/`libssl`, `psych`/`libyaml`, `zlib`/`libz`, and non-UTF CJK transcoders) and removes unused static CJK transcoding lookup table data segments.
4. **Binaryen `wasm-opt -Oz` (~0.6 MB saved)**: Runs `wasm-opt -Oz` when available in `PATH`, reducing the final `dist/cdd-ruby.wasm` from ~81 MB (`70.3 MB`) down to **~9.3 MB** (~87% smaller).

## Integration

The generated `dist/cdd-ruby.wasm` can be used directly with standard WASM runtimes (like Wasmtime, Wasmer, or Node.js) and can also run in modern web browsers.

This allows seamless integration into the unified CLI of all `cdd-*` projects and the unified web interface.
