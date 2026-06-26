#!/usr/bin/env python3
import os
import subprocess
import glob
import shutil
import sys

bin_dir = os.environ.get('BIN_DIR', 'bin')
os.makedirs(bin_dir, exist_ok=True)

if subprocess.run(['gem', 'build', 'cdd-ruby.gemspec']).returncode != 0:
    print('Failed to build gem')
    sys.exit(1)

gem_files = glob.glob('cdd-ruby-*.gem')
if gem_files:
    gem_file = gem_files[0]
    shutil.move(gem_file, os.path.join(bin_dir, gem_file))
else:
    print('Gem file not found after build')
    sys.exit(1)
