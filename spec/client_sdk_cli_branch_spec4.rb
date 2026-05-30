# frozen_string_literal: true

require_relative 'spec_helper'
require 'tempfile'

class ClientSdkCliBranchTest4 < Minitest::Test
  def test_client_sdk_cli_emit_components
    openapi = {
      'openapi' => '3.0.0',
      'components' => {
        'schemas' => {
          'S' => { 'discriminator' => { 'propertyName' => 'p', 'mapping' => nil } }
        }
      }
    }
    file = Tempfile.new(['openapi', '.json'])
    file.write(openapi.to_json)
    file.close
    out = Cdd::ClientSdkCli::Emitter.emit_sdk_cli(input: file.path)
    refute_nil out
    file.unlink
  end
end
