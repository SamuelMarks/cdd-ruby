# frozen_string_literal: true

require_relative 'spec_helper'
require 'tempfile'
require 'fileutils'

class ClientSdkBranchTest2 < Minitest::Test
  def test_client_sdk_emit_missing_ops
    openapi = {
      'openapi' => '3.0.0',
      'paths' => {
        '/test' => {
          'get' => {
            'parameters' => [
              { 'name' => 'p2', 'in' => 'body', 'schema' => { 'type' => 'array' } },
              { 'name' => 'p3', 'in' => 'body', 'schema' => { 'type' => 'string' } }
            ],
            'requestBody' => {
              'content' => { 'application/json' => { 'schema' => { 'type' => 'string' } } }
            }
          }
        }
      },
      'components' => nil
    }
    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close

    out_dir = Dir.mktmpdir
    Cdd::ClientSdk::Emitter.emit_sdk(input: file.path, output: out_dir, tests: true, no_github_actions: true, no_installable_package: true)

    file.unlink
    FileUtils.rm_rf(out_dir)
  end

  def test_client_sdk_emit_missing_components
    openapi = {
      'openapi' => '3.0.0',
      'components' => {
        'schemas' => {
          'A' => {
            'example' => false,
            'properties' => nil
          }
        }
      }
    }
    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close
    out = Cdd::ClientSdk::Emitter.emit_sdk(input: file.path)
    refute_nil out
    file.unlink
  end
end
