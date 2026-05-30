# frozen_string_literal: true

require_relative 'spec_helper'
require 'tempfile'

class ScaffoldingBranchTest < Minitest::Test
  def test_scaffolding_branches
    Dir.mktmpdir do |dir|
      Cdd::Scaffolding.generate({ output: dir, no_github_actions: true, no_installable_package: true }, 'client')
    end

    Dir.mktmpdir do |dir|
      # Pre-create files to trigger "unless Dir.glob"
      File.write(File.join(dir, 'cdd_sdk.gemspec'), '')
      File.write(File.join(dir, 'Gemfile'), '')
      Cdd::Scaffolding.generate({ output: dir }, 'server')
    end

    # Test Dir.exist? out_dir branch
    Cdd::Scaffolding.generate({ output: Dir.pwd, no_github_actions: true, no_installable_package: true }, 'client')
  end
end
