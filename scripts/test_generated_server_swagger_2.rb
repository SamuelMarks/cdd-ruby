#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'net/http'
require 'uri'

sdk_dir = File.expand_path('../../cdd-ruby-client-v2-generated-server', __dir__)
server_dir = File.expand_path('../../cdd-ruby-server-v2-generated', __dir__)
project_root = File.expand_path('..', __dir__)
petstore_json = File.expand_path('../../petstore.json', __dir__)

FileUtils.rm_rf(sdk_dir)
FileUtils.rm_rf(server_dir)

Dir.chdir(project_root) do
  unless system("bundle exec ruby bin/cdd-ruby from_openapi to_sdk -i \"#{petstore_json}\" -o \"#{sdk_dir}\"")
    puts 'Failed to generate SDK for Swagger 2.0'
    exit 1
  end

  unless system("bundle exec ruby bin/cdd-ruby from_openapi to_server -i \"#{petstore_json}\" -o \"#{server_dir}\" --with-ephemeral")
    puts 'Failed to generate Server for Swagger 2.0'
    exit 1
  end
end

# Make sure server dependencies are installed
Dir.chdir(server_dir) do
  unless system('bundle install')
    puts 'Failed to install server dependencies'
    exit 1
  end
end

srand(Process.pid)
port = rand(8000..8999)

puts 'Attempting to start generated server...'
server_pid = spawn("bundle exec ruby server.rb -p #{port} --ephemeral", chdir: server_dir)

server_ready = false
base_path = ''
30.times do
  begin
    res = Net::HTTP.get_response(URI("http://localhost:#{port}#{base_path}/pet/findByStatus?status=available"))
    if res.is_a?(Net::HTTPSuccess) || res.code == '404' || res.code == '501' || res.code == '200' || res.code == '401'
      server_ready = true
      break
    end
  rescue StandardError
    # ignore
  end
  sleep 2
end

unless server_ready
  puts 'Generated server failed to respond.'
  begin
    Process.kill('TERM', server_pid)
  rescue StandardError
    nil
  end
  exit 1
end

if Dir.exist?(sdk_dir)
  Dir.chdir(sdk_dir) do
    FileUtils.mkdir_p('spec')
    File.write('spec/client_spec.rb', <<~SPEC)
      require_relative '../lib/client'

      RSpec.describe ClientSdk do
        let(:client) { ClientSdk.new('http://localhost:#{port}#{base_path}') }

        it 'calls the endpoint (which may return 200, 401 or 501)' do
          begin
            response = client.findPetsByStatus(status: 'available')
            expect(['200', '401', '501']).to include(client.last_response.code)
          rescue StandardError => e
            fail "Failed to call endpoint: \#{e.message}"
          end
        end
      end
    SPEC

    File.open('Gemfile', 'a') { |f| f.puts "gem 'rspec'" } unless File.read('Gemfile').include?('rspec')

    system('bundle install')
    unless system('bundle exec rspec')
      puts 'RSpec failed!'
      begin
        Process.kill('TERM', server_pid)
      rescue StandardError
        nil
      end
      exit 1
    end
  end
end

begin
  Process.kill('TERM', server_pid)
rescue StandardError
  nil
end
begin
  Process.wait(server_pid)
rescue StandardError
  nil
end
FileUtils.rm_rf(sdk_dir)
FileUtils.rm_rf(server_dir)
