# frozen_string_literal: true

require_relative 'spec_helper'
require 'tempfile'
require 'fileutils'

class ClientSdkBranchTest3 < Minitest::Test
  def test_client_sdk_emit_missing_components
    openapi = {
      'openapi' => '3.0.0',
      'paths' => {
        '/test' => {
          'get' => {
            'summary' => 'Summary String',
            'requestBody' => {
              'content' => nil # For line 102
            },
            'parameters' => [
              { 'name' => 'status', 'in' => 'query', 'schema' => { 'type' => 'string' } }
            ]
          }
        }
      }
    }
    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close
    out_dir = Dir.mktmpdir
    out = Cdd::ClientSdk::Emitter.emit_sdk(input: file.path, output: out_dir, tests: true, no_github_actions: true, no_installable_package: true)
    refute_nil out
    file.unlink
    FileUtils.rm_rf(out_dir)
  end

  def test_client_sdk_emit_missing_components2
    openapi = {
      'openapi' => '3.0.0',
      'paths' => nil,
      'components' => {
        'examples' => {
          'E1' => {}
        }
      }
    }
    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close
    out_dir = Dir.mktmpdir
    out = Cdd::ClientSdk::Emitter.emit_sdk(input: file.path, output: out_dir, tests: true, no_github_actions: true, no_installable_package: true)
    refute_nil out
    file.unlink
    FileUtils.rm_rf(out_dir)
  end
end
