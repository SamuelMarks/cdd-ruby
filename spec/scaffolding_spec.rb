# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../src/scaffolding'
require 'fileutils'

class ScaffoldingTest < Minitest::Test
  def setup
    @out_dir = 'scaffolding_unit_test'
    FileUtils.rm_rf(@out_dir)
  end

  def teardown
    FileUtils.rm_rf(@out_dir)
  end

  def test_generate_server
    options = { output: @out_dir, no_installable_package: false, no_github_actions: false }
    Cdd::Scaffolding.generate(options, 'server', 'test_proj')
    assert File.exist?(File.join(@out_dir, 'test_proj.gemspec'))
    assert File.exist?(File.join(@out_dir, 'Gemfile'))
    assert File.read(File.join(@out_dir, 'Gemfile')).include?("gem 'sinatra'")
    assert File.exist?(File.join(@out_dir, '.rubocop.yml'))
    assert File.exist?(File.join(@out_dir, 'README.md'))
    readme_content = File.read(File.join(@out_dir, 'README.md'))
    assert readme_content.include?('## Server Modes')
    assert readme_content.include?('### 1. Stub Mode')
    assert readme_content.include?('### 4. Full Mock Mode')
    assert File.exist?(File.join(@out_dir, '.github/workflows/ci.yml'))

    # Run again to hit the "already exists" paths
    Cdd::Scaffolding.generate(options, 'server', 'test_proj')
  end

  def test_generate_server_with_ephemeral
    options = { output: @out_dir, no_installable_package: false, no_github_actions: false, with_ephemeral: true }
    Cdd::Scaffolding.generate(options, 'server', 'test_proj_ephemeral')
    gemfile_content = File.read(File.join(@out_dir, 'Gemfile'))
    gemspec_content = File.read(File.join(@out_dir, 'test_proj_ephemeral.gemspec'))
    assert gemfile_content.include?("gem 'activerecord'")
    assert gemfile_content.include?("gem 'sqlite3'")
    assert gemspec_content.include?("spec.add_dependency 'activerecord'")
    assert gemspec_content.include?("spec.add_dependency 'sqlite3'")
    refute gemfile_content.include?("gem 'faker'")
  end

  def test_generate_server_with_seed
    options = { output: @out_dir, no_installable_package: false, no_github_actions: false, with_seed: true }
    Cdd::Scaffolding.generate(options, 'server', 'test_proj_seed')
    gemfile_content = File.read(File.join(@out_dir, 'Gemfile'))
    gemspec_content = File.read(File.join(@out_dir, 'test_proj_seed.gemspec'))
    assert gemfile_content.include?("gem 'activerecord'")
    assert gemfile_content.include?("gem 'sqlite3'")
    assert gemfile_content.include?("gem 'faker'")
    assert gemspec_content.include?("spec.add_dependency 'faker'")
  end
end
