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
      FileUtils.mkdir_p(out_dir)

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
              spec.add_development_dependency "rubocop", "~> 1.60"
          GEMSPEC

          if type == 'server'
            gemspec += "  spec.add_dependency 'sinatra', '~> 4.0'\n"
            gemspec += "  spec.add_dependency 'webrick', '~> 1.8'\n"
            gemspec += "  spec.add_dependency 'puma', '~> 6.4'\n"
            gemspec += "  spec.add_dependency 'rackup', '~> 2.1'\n"
            gemspec += "  spec.add_development_dependency 'minitest', '~> 5.0'\n"
            gemspec += "  spec.add_development_dependency 'rack-test', '~> 2.1'\n"
            if options[:with_ephemeral] || options[:with_seed]
              gemspec += "  spec.add_dependency 'activerecord', '~> 8.0'\n"
              gemspec += "  spec.add_dependency 'sqlite3', '~> 2.0'\n"
            end
            gemspec += "  spec.add_dependency 'faker', '~> 3.5'\n" if options[:with_seed]
          end

          gemspec += "end\n"
          File.write(gemspec_path, gemspec)
        end

        gemfile_path = File.join(out_dir, 'Gemfile')
        unless File.exist?(gemfile_path)
          gemfile = <<~GEMFILE
            source 'https://rubygems.org'
            gemspec
            gem 'rspec', group: :test
            gem 'rubocop', group: :development
          GEMFILE
          if type == 'server'
            gemfile += "gem 'sinatra'\n"
            gemfile += "gem 'webrick'\n"
            gemfile += "gem 'puma'\n"
            gemfile += "gem 'rackup'\n"
            gemfile += "gem 'minitest', group: :test\n"
            gemfile += "gem 'rack-test', group: :test\n"
            if options[:with_ephemeral] || options[:with_seed]
              gemfile += "gem 'activerecord'\n"
              gemfile += "gem 'sqlite3'\n"
            end
            gemfile += "gem 'faker'\n" if options[:with_seed]
          end
          File.write(gemfile_path, gemfile)
        end

        rubocop_path = File.join(out_dir, '.rubocop.yml')
        unless File.exist?(rubocop_path)
          rubocop_config = <<~RUBOCOP
            AllCops:
              NewCops: enable
              Exclude:
                - 'vendor/**/*'
            Style/Documentation:
              Enabled: true
          RUBOCOP
          File.write(rubocop_path, rubocop_config)
        end

        readme_path = File.join(out_dir, 'README.md')
        unless File.exist?(readme_path)
          readme = "# #{project_name}\n\nThis is an auto-generated #{type} project.\n\n"
          if type == 'server'
            readme += <<~README
              ## Server Modes

              This CDD server supports multiple decoupled execution modes, allowing it to seamlessly transition between traditional scaffolding, throwaway sandbox testing, and actual database persistence.

              ### 1. Stub Mode
              `ruby server.rb` (No DB configured)
              The server runs using traditional scaffolds. All endpoints safely return `NotImplementedError` or empty default bodies. This is ideal for initial client integration before the business logic is wired up.

              ### 2. Production Mode
              `ruby server.rb` (With `DATABASE_URL` set)
              The server connects to an external database via ActiveRecord. It persists state and acts as a standard relational backend.

              ### 3. Sandbox Mode
              `ruby server.rb --ephemeral`
              The server overrides the database connection to use a fresh, throwaway in-memory database (`sqlite3::memory:`). It automatically runs migrations on startup. This is ideal for isolated, stateful integration testing.

              ### 4. Full Mock Mode
              `ruby server.rb --ephemeral --seed`
              The server uses a throwaway database, but automatically populates it on startup using localized fake data generation. It topologically traverses the data models to generate a rich, referentially sound dependency graph.

              ## Administrative Endpoints
              If your specification dictates Webhooks or Callbacks, this server exposes an administrative trigger endpoint:
              `POST /_mock/trigger-webhook/{webhook_name}`

              You can invoke it with a `target_url` payload to instruct the mock server to dispatch a simulated outbound payload.
            README
          end

          readme += <<~README

            ## Unified CLI Toolset

            This project is generated and maintained utilizing the unified `cdd` CLI toolset. This toolset guarantees that the Server, SDKs, Database Models, and OpenAPI specification remain in absolute harmony.

            ### `from_openapi`
            Generates code artifacts from the OpenAPI definition.
            - `cdd from_openapi to_server -i spec.json -o out_dir`
            - `cdd from_openapi to_sdk -i spec.json -o out_dir`
            - `cdd from_openapi to_sdk_cli -i spec.json -o out_dir`

            ### `to_openapi`
            Reverse-generates the OpenAPI specification directly from the runtime source code (route handlers, DAOs, classes).
            - `cdd to_openapi -i out_dir/server.rb -o runtime_spec.json`

            ### `sync`
            Bidirectionally synchronizes contract drift between the specification and the codebase.
            - `cdd sync -i spec.json --truth class`
            - `cdd sync -i spec.json --truth activerecord`
            - `cdd sync -i spec.json --truth function`

            By designating a single source of truth, changes to one domain (e.g., adding an ActiveRecord property or a Sinatra route) dynamically propagate back into the specification, ensuring mathematical equivalence across the stack.
          README

          File.write(readme_path, readme)
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
              - uses: actions/checkout@v6
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
