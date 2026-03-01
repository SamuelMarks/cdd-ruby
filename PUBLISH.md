# Publishing cdd-ruby

## RubyGems

1. Bump the version in `cdd-ruby.gemspec`.
2. Run `gem build cdd-ruby.gemspec`.
3. Run `gem push cdd-ruby-1.0.0.gem`.

## Docs

1. Run `make build_docs`.
2. Deploy the `docs/` folder to your static site host (e.g., GitHub Pages).
