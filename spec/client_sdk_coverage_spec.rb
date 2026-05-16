# frozen_string_literal: true

require_relative 'spec_helper'
require 'tempfile'
require 'json'
require 'fileutils'

class ClientSdkCoverageTest < Minitest::Test
  def test_client_sdk_swagger_2_0_coverage
    spec = {
      'openapi' => '2.0',
      'host' => 'api.example.com',
      'basePath' => '/v2',
      'paths' => {
        '/test_form' => {
          'post' => {
            'operationId' => 'testForm',
            'consumes' => ['application/x-www-form-urlencoded'],
            'security' => [{ 'petstore_auth' => ['write:pets', 'read:pets'] }],
            'parameters' => [
              { 'name' => 'q1', 'in' => 'query', 'type' => 'string' },
              { 'name' => 'h1', 'in' => 'header', 'type' => 'string' },
              { 'name' => 'f1', 'in' => 'formData', 'type' => 'string' },
              { 'name' => 'b1', 'in' => 'body', 'schema' => { 'type' => 'object' } }
            ],
            'responses' => { '200' => { 'description' => 'OK' } }
          }
        },
        '/test_body_arr' => {
          'post' => {
            'operationId' => 'testBodyArr',
            'parameters' => [
              { 'name' => 'b2', 'in' => 'body', 'schema' => { 'type' => 'array' } }
            ]
          }
        },
        '/test_multipart' => {
          'post' => {
            'operationId' => 'testMultipart',
            'consumes' => ['multipart/form-data']
          }
        }
      }
    }
    
    file = Tempfile.new('openapi.json')
    file.write(spec.to_json)
    file.close
    
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'lib'))
      FileUtils.mkdir_p(File.join(dir, 'spec'))
      Cdd::ClientSdk::Emitter.emit_sdk({ input: file.path, output: dir })
      out = File.read(File.join(dir, 'lib', 'client.rb'))
      assert_match(/api\.example\.com\/v2/, out)
      assert_match(/header_params\.keys\.each/, out)
      assert_match(/req\['api_key'\] = 'special-key'/, out)
      assert_match(/req.set_form.*\/x-www-form-urlencoded'/, out)
      assert_match(/req.set_form.*\/form-data'/, out)
    end
  ensure
    file.unlink
  end

  def test_client_sdk_openapi_3_0_coverage
    spec = {
      'openapi' => '3.0.0',
      'paths' => {
        '/test_o3_form' => {
          'post' => {
            'operationId' => 'testO3Form',
            'requestBody' => {
              'content' => {
                'application/x-www-form-urlencoded' => { 'schema' => { 'type' => 'object' } }
              }
            }
          }
        },
        '/test_o3_multipart' => {
          'post' => {
            'operationId' => 'testO3Multipart',
            'requestBody' => {
              'content' => {
                'multipart/form-data' => { 'schema' => { 'type' => 'object' } }
              }
            }
          }
        },
        '/test_o3_arr' => {
          'post' => {
            'operationId' => 'testO3Arr',
            'requestBody' => {
              'content' => {
                'application/json' => { 'schema' => { 'type' => 'array' } }
              }
            }
          }
        }
      }
    }
    file = Tempfile.new('openapi.json')
    file.write(spec.to_json)
    file.close
    
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'lib'))
      FileUtils.mkdir_p(File.join(dir, 'spec'))
      Cdd::ClientSdk::Emitter.emit_sdk({ input: file.path, output: dir })
      out = File.read(File.join(dir, 'spec', 'integration_spec.rb'))
      assert_match(/'body' => \[\{ 'id' => 1/, out)
    end
  ensure
    file.unlink
  end
end

class ClientSdkCoverageMissedTest < Minitest::Test
  def test_missed_coverage
    spec = {
      'openapi' => '2.0',
      'basePath' => '/v3',
      'paths' => {
        '/test' => {
          'post' => {
            'operationId' => 'testMissed',
            'consumes' => ['application/xml']
          }
        }
      }
    }
    file = Tempfile.new('openapi.json')
    file.write(spec.to_json)
    file.close
    
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'lib'))
      FileUtils.mkdir_p(File.join(dir, 'spec'))
      Cdd::ClientSdk::Emitter.emit_sdk({ input: file.path, output: dir })
      out = File.read(File.join(dir, 'lib', 'client.rb'))
      assert_match(/base_url = 'http:\/\/localhost\/v3'/, out)
      assert_match(/'application\/xml'/, out) # Note this regex might need adjustment depending on what is emitted
    end
  ensure
    file.unlink
  end
end
