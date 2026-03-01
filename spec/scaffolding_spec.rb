require_relative 'spec_helper'
require_relative '../src/scaffolding'
require 'fileutils'

class ScaffoldingTest < Minitest::Test
  def setup
    @out_dir = "scaffolding_unit_test"
    FileUtils.rm_rf(@out_dir)
  end

  def teardown
    FileUtils.rm_rf(@out_dir)
  end

  def test_generate_server
    options = { output: @out_dir, no_installable_package: false, no_github_actions: false }
    Cdd::Scaffolding.generate(options, 'server', 'test_proj')
    assert File.exist?(File.join(@out_dir, "test_proj.gemspec"))
    assert File.exist?(File.join(@out_dir, "Gemfile"))
    assert File.read(File.join(@out_dir, "Gemfile")).include?("gem 'sinatra'")
    assert File.exist?(File.join(@out_dir, ".github/workflows/ci.yml"))
    
    # Run again to hit the "already exists" paths
    Cdd::Scaffolding.generate(options, 'server', 'test_proj')
  end
end
