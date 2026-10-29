# frozen_string_literal: true

require 'fileutils'
require_relative 'error'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Scaffolding class generates project packaging, documentation, and CI workflow files.
  class Scaffolding
    # Generates gemspec, Gemfile, `.rubocop.yml`, `README.md`, and CI workflows.
    #
    # @param options [Hash] CLI options containing `:output`, `:no_installable_package`, `:no_github_actions`
    # @param type [String] type of project (`'sdk'`, `'sdk_cli'`, `'server'`)
    # @param project_name [String] name of the generated project
    # @return [nil]
    def self.generate(options, type, project_name = 'generated_project')
      out_dir = options[:output] || Dir.pwd
      FileUtils.mkdir_p(out_dir)

      unless options[:no_installable_package]
        write_gemspec(out_dir, options, type, project_name)
        write_gemfile(out_dir, options, type)
        write_rakefile(out_dir)
        write_rubocop_yml(out_dir)
        write_readme(out_dir, type, project_name)
      end

      write_github_workflow(out_dir) unless options[:no_github_actions]
      nil
    end

    # Writes `<project_name>.gemspec` if no gemspec exists in `out_dir`.
    #
    # @param out_dir [String] target directory
    # @param options [Hash] CLI options
    # @param type [String] project type
    # @param project_name [String] project name
    # @return [void]
    def self.write_gemspec(out_dir, options, type, project_name)
      return if Dir.glob(File.join(out_dir, '*.gemspec')).any?

      gemspec = <<~GEMSPEC
        Gem::Specification.new do |spec|
          spec.name          = "#{project_name}"
          spec.version       = "#{Cdd::VERSION}"
          spec.authors       = ["CDD Generator"]
          spec.summary       = "Auto-generated #{type}"
          spec.files         = Dir.glob("**/*.rb")
          spec.require_paths = ["lib"]
          spec.add_development_dependency "rake", "~> 13.0"
          spec.add_development_dependency "rspec", "~> 3.0"
          spec.add_development_dependency "rubocop", "~> 1.60"
      GEMSPEC
      gemspec += server_gemspec_deps(options) if type == 'server'
      File.write(File.join(out_dir, "#{project_name}.gemspec"), "#{gemspec}end\n")
    end

    # Builds the server-specific dependency lines for a generated gemspec.
    #
    # @param options [Hash] CLI options
    # @return [String] gemspec dependency lines
    def self.server_gemspec_deps(options)
      deps = "  spec.add_dependency 'sinatra', '~> 4.0'\n  " \
             "spec.add_dependency 'webrick', '~> 1.8'\n  " \
             "spec.add_dependency 'puma', '~> 6.4'\n  " \
             "spec.add_dependency 'rackup', '~> 2.1'\n  " \
             "spec.add_development_dependency 'minitest', '~> 5.0'\n  " \
             "spec.add_development_dependency 'rack-test', '~> 2.1'\n"
      if options[:with_ephemeral] || options[:with_seed]
        deps += "  spec.add_dependency 'activerecord', '~> 8.0'\n  " \
                "spec.add_dependency 'sqlite3', '~> 2.0'\n"
      end
      deps += "  spec.add_dependency 'faker', '~> 3.5'\n" if options[:with_seed]
      deps
    end

    # Writes `Gemfile` if not already present in `out_dir`.
    #
    # @param out_dir [String] target directory
    # @param options [Hash] CLI options
    # @param type [String] project type
    # @return [void]
    def self.write_gemfile(out_dir, options, type)
      gemfile_path = File.join(out_dir, 'Gemfile')
      return if File.exist?(gemfile_path)

      gemfile = <<~GEMFILE
        source 'https://rubygems.org'
        gemspec
        gem 'rake', '~> 13.0'
        gem 'rspec', group: :test
        gem 'rubocop', group: :development
      GEMFILE
      gemfile += server_gemfile_deps(options) if type == 'server'
      File.write(gemfile_path, gemfile)
    end

    # Writes `Rakefile` with `task :test` delegating to `rspec` if not already present in `out_dir`.
    #
    # @param out_dir [String] target directory
    # @return [void]
    def self.write_rakefile(out_dir)
      rakefile_path = File.join(out_dir, 'Rakefile')
      return if File.exist?(rakefile_path)

      rakefile = <<~RAKEFILE
        # frozen_string_literal: true

        desc 'Run tests'
        task :test do
          sh 'bundle exec rspec'
        end

        task default: :test
      RAKEFILE
      File.write(rakefile_path, rakefile)
    end

    # Builds the server-specific gem lines for a generated `Gemfile`.
    #
    # @param options [Hash] CLI options
    # @return [String] Gemfile lines
    def self.server_gemfile_deps(options)
      deps = "gem 'sinatra'\ngem 'webrick'\ngem 'puma'\ngem 'rackup'\n" \
             "gem 'minitest', group: :test\ngem 'rack-test', group: :test\n"
      deps += "gem 'activerecord'\ngem 'sqlite3'\n" if options[:with_ephemeral] || options[:with_seed]
      deps += "gem 'faker'\n" if options[:with_seed]
      deps
    end

    # Writes `.rubocop.yml` if not already present in `out_dir`.
    #
    # @param out_dir [String] target directory
    # @return [void]
    def self.write_rubocop_yml(out_dir)
      rubocop_path = File.join(out_dir, '.rubocop.yml')
      return if File.exist?(rubocop_path)

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

    # Writes `README.md` if not already present in `out_dir`.
    #
    # @param out_dir [String] target directory
    # @param type [String] project type
    # @param project_name [String] project name
    # @return [void]
    def self.write_readme(out_dir, type, project_name)
      readme_path = File.join(out_dir, 'README.md')
      return if File.exist?(readme_path)

      readme = "# #{project_name}\n\nThis is an auto-generated #{type} project.\n\n"
      readme += server_readme_section if type == 'server'
      readme += unified_cli_readme_section
      File.write(readme_path, readme)
    end

    # Returns the server execution modes section for generated `README.md` files.
    #
    # @return [String] Markdown section
    def self.server_readme_section
      <<~README
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

    # Returns the unified CLI toolset section for generated `README.md` files.
    #
    # @return [String] Markdown section
    def self.unified_cli_readme_section
      <<~README

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
    end

    # Writes `.github/workflows/ci.yml` if not already present in `out_dir`.
    #
    # @param out_dir [String] target directory
    # @return [void]
    def self.write_github_workflow(out_dir)
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
