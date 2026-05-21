#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'

dir = File.expand_path('../../cdd-ruby-client-v3', __dir__)
project_root = File.expand_path('..', __dir__)
petstore_json = File.expand_path('../../petstore_oas3.json', __dir__)

FileUtils.rm_rf(dir)

Dir.chdir(project_root) do
  unless system("bundle exec ruby bin/cdd-ruby from_openapi to_sdk -i \"#{petstore_json}\" -o \"#{dir}\"")
    puts 'Failed to generate SDK for OpenAPI 3.2.0'
    exit 1
  end
end

if Dir.exist?(dir)
  Dir.chdir(dir) do
    system('bundle install')
    # Ignore rspec failure due to missing mock server (as in original bash script)
    system('bundle exec rspec')
  end
end

FileUtils.rm_rf(dir)
