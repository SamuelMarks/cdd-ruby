# frozen_string_literal: true

require 'fileutils'

module Cdd
  # Scaffolding class generates basic project files
  class Scaffolding
    # Generates gemspec, Gemfile, and CI workflows
    # @param options [Hash] CLI options containing output directory
    # @param type [String] Type of project (e.g. sdk, server)
    # @param project_name [String] Name of the project
    # @return [nil]
    def self.generate(options, type, project_name = 'generated_project')
      out_dir = options[:output] || Dir.pwd
      FileUtils.mkdir_p(out_dir) unless Dir.exist?(out_dir)

      unless options[:no_installable_package]
        gemspec_path = File.join(out_dir, "#{project_name}.gemspec")
        unless Dir.glob(File.join(out_dir, '*.gemspec')).any?
          gemspec = <<~GEMSPEC
            Gem::Specification.new do |spec|
              spec.name          = "#{project_name}"
              spec.version       = "0.1.0"
              spec.authors       = ["CDD Generator"]
              spec.summary       = "Auto-generated #{type}"
              spec.files         = Dir.glob("**/*.rb")
              spec.require_paths = ["lib"]
              spec.add_development_dependency "rspec", "~> 3.0"
            end
          GEMSPEC
          File.write(gemspec_path, gemspec)
        end

        gemfile_path = File.join(out_dir, 'Gemfile')
        unless File.exist?(gemfile_path)
          gemfile = <<~GEMFILE
            source 'https://rubygems.org'
            gemspec
            gem 'rspec', group: :test
          GEMFILE
          gemfile += "gem 'sinatra'\n" if type == 'server'
          File.write(gemfile_path, gemfile)
        end
      end

      return if options[:no_github_actions]

      gh_dir = File.join(out_dir, '.github', 'workflows')
      FileUtils.mkdir_p(gh_dir)
      ci_path = File.join(gh_dir, 'ci.yml')
      return if File.exist?(ci_path)

      ci = <<~CI
        name: CI
        on: [push, pull_request]
        jobs:
          test:
            runs-on: ubuntu-latest
            steps:
              - uses: actions/checkout@v3
              - uses: ruby/setup-ruby@v1
                with:
                  ruby-version: '3.4'
              - run: bundle install
              # - run: bundle exec rspec
      CI
      File.write(ci_path, ci)
    end
  end
end
