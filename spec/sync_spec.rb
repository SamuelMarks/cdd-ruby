# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../src/sync'
require 'fileutils'
require 'json'

class SyncTest < Minitest::Test
  def setup
    @out_dir = 'sync_unit_test'
    FileUtils.mkdir_p(@out_dir)
    @json_path = File.join(@out_dir, 'spec.json')
    File.write(@json_path, { openapi: '3.0.0', components: { schemas: {} }, paths: {} }.to_json)
  end

  def teardown
    FileUtils.rm_rf(@out_dir)
  end

  def test_sync_classes
    File.write(File.join(@out_dir, 'model.rb'), <<~RUBY)
      class User < ActiveRecord::Base
        # property: email (string)
      end
    RUBY

    Cdd::Sync.sync(@json_path, 'class')
    spec = JSON.parse(File.read(@json_path))
    assert_equal 'string', spec['components']['schemas']['User']['properties']['email']['type']
  end

  def test_sync_functions
    File.write(File.join(@out_dir, 'routes.rb'), <<~RUBY)
      get '/ping' do
        "pong"
      end
    RUBY

    Cdd::Sync.sync(@json_path, 'function')
    spec = JSON.parse(File.read(@json_path))
    assert spec['paths']['/ping']['get']
  end

  def test_sync_skip_test_dirs
    spec_subdir = File.join(@out_dir, 'spec')
    FileUtils.mkdir_p(spec_subdir)
    File.write(File.join(spec_subdir, 'ignored.rb'), <<~RUBY)
      class IgnoredClass
      end
    RUBY

    Cdd::Sync.sync(@json_path, 'class')
    spec = JSON.parse(File.read(@json_path))
    refute spec['components']['schemas']['IgnoredClass']
  end
end
