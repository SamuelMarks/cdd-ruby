#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys

for ruby_bin in ('/opt/homebrew/opt/ruby/bin', '/usr/local/opt/ruby/bin'):
    if os.path.isdir(ruby_bin):
        os.environ['PATH'] = f"{ruby_bin}{os.pathsep}{os.environ.get('PATH', '')}"

if shutil.which('rbwasm') is None:
    print('rbwasm not found in PATH; skipping WASM build.')
    sys.exit(0)

bin_dir = os.environ.get('BIN_DIR', 'dist')
os.makedirs(bin_dir, exist_ok=True)

print('Building WASM via ruby-wasm. It requires ruby.wasm packager.')

ruby_wasm_path = os.path.join(bin_dir, 'ruby.wasm')
if subprocess.run(['rbwasm', 'build', '-o', ruby_wasm_path, '--disable-gems']).returncode != 0:
    print('Failed to build ruby.wasm')
    sys.exit(1)

cdd_ruby_wasm_path = os.path.join(bin_dir, 'cdd-ruby.wasm')
if subprocess.run(['rbwasm', 'pack', ruby_wasm_path, '--dir', 'src::/src', '--dir', 'bin::/bin', '-o', cdd_ruby_wasm_path]).returncode != 0:
    print('Failed to pack wasm')
    sys.exit(1)
