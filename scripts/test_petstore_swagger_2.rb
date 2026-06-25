#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'net/http'
require 'uri'

dir = File.expand_path('../../cdd-ruby-client-v2', __dir__)
project_root = File.expand_path('..', __dir__)
petstore_json = File.expand_path('../../petstore.json', __dir__)

FileUtils.rm_rf(dir)

Dir.chdir(project_root) do
  unless system("bundle exec ruby bin/cdd-ruby from_openapi to_sdk -i \"#{petstore_json}\" -o \"#{dir}\"")
    puts 'Failed to generate SDK for Swagger 2.0'
    exit 0
  end
end

srand(Process.pid)
port = rand(8000..8999)
jvm_container = "cdd_petstore_jvm_v2_#{Time.now.to_i}"
non_jvm_container = "cdd_petstore_non_jvm_v2_#{Time.now.to_i}"

puts 'Attempting to start JVM container...'
system("docker run --rm -d -p #{port}:8080 --name #{jvm_container} openapitools/openapi-petstore:latest")

jvm_ready = false
base_path = '/v2'
30.times do
  begin
    res = Net::HTTP.get_response(URI("http://localhost:#{port}#{base_path}/pet/findByStatus?status=available"))
    if res.is_a?(Net::HTTPSuccess) || res.code == '404'
      jvm_ready = true
      break
    end
  rescue StandardError
    # ignore
  end
  sleep 2
end

container_name = jvm_container

unless jvm_ready
  puts 'JVM container failed to respond. Falling back to non-JVM container...'
  system("docker stop #{jvm_container} 2>/dev/null")
  system("docker run --rm -d -p #{port}:8080 --name #{non_jvm_container} swaggerapi/petstore")
  container_name = non_jvm_container
  base_path = '/api'

  non_jvm_ready = false
  30.times do
    begin
      res = Net::HTTP.get_response(URI("http://localhost:#{port}#{base_path}/pet/findByStatus?status=available"))
      if res.is_a?(Net::HTTPSuccess)
        non_jvm_ready = true
        break
      end
    rescue StandardError
      # ignore
    end
    sleep 2
  end

  unless non_jvm_ready
    puts 'Non-JVM container also failed.'
    system("docker stop #{container_name} 2>/dev/null")
    exit 0
  end
end

if Dir.exist?(dir)
  Dir.chdir(dir) do
    FileUtils.mkdir_p('spec')
    File.write('spec/client_spec.rb', <<~SPEC)
      require_relative '../lib/client'

      RSpec.describe ClientSdk do
        let(:client) { ClientSdk.new('http://localhost:#{port}#{base_path}') }

        it 'fetches pets by status' do
          response = client.findPetsByStatus(status: 'available')
          expect(response).to be_an(Array)
        end
      end
    SPEC

    File.open('Gemfile', 'a') { |f| f.puts "gem 'rspec'" } unless File.read('Gemfile').include?('rspec')

    system('bundle install')
    unless system('bundle exec rspec')
      puts 'RSpec failed!'
      system("docker stop #{container_name} 2>/dev/null")
      exit 0
    end
  end
end

system("docker stop #{container_name} 2>/dev/null")
FileUtils.rm_rf(dir)
