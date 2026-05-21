#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'

bin_dir = ENV['BIN_DIR'] || 'dist'
FileUtils.mkdir_p(bin_dir)

puts 'Building WASM via ruby-wasm. It requires ruby.wasm packager.'

unless system("rbwasm build -o #{File.join(bin_dir, 'ruby.wasm')} --disable-gems")
  puts 'Failed to build ruby.wasm'
  exit 1
end

unless system("rbwasm pack #{File.join(bin_dir, 'ruby.wasm')} --dir src::/src --dir bin::/bin -o #{File.join(bin_dir, 'cdd-ruby.wasm')}")
  puts 'Failed to pack wasm'
  exit 1
end
