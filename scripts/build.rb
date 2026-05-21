#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'

bin_dir = ENV['BIN_DIR'] || 'bin'
FileUtils.mkdir_p(bin_dir)

unless system('gem build cdd-ruby.gemspec')
  puts 'Failed to build gem'
  exit 1
end

gem_file = Dir.glob('cdd-ruby-*.gem').first
if gem_file
  FileUtils.mv(gem_file, File.join(bin_dir, gem_file), force: true)
else
  puts 'Gem file not found after build'
  exit 1
end
