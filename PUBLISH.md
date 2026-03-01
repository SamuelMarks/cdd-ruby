# Publishing the cdd-ruby Compiler

This guide covers how to publish the `cdd-ruby` gem to rubygems.org and how to host your documentation locally.

## Publishing the Gem

1. Ensure the version is correct in `cdd-ruby.gemspec` and `bin/cdd-ruby`.
2. Ensure you have a rubygems account and are logged in via `gem signin`.
3. Build the gem using the make command:
   ```bash
   make build
   ```
4. Push the generated gem to RubyGems:
   ```bash
   gem push cdd-ruby-0.0.1.gem
   ```

## Building & Hosting Docs

We use YARD for generating code documentation.

1. Build docs locally:
   ```bash
   make build_docs
   ```
   This will output HTML documentation into the `docs` directory.
2. Serve locally:
   ```bash
   ruby -run -e httpd docs -p 8080
   ```
3. To host on GitHub Pages, set up an action to deploy the `docs` folder to the `gh-pages` branch.
