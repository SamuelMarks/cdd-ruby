# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'cdd-ruby'
  spec.version = '0.0.4'
  spec.authors       = ['CDD Developer']
  spec.email         = ['developer@example.com']
  spec.summary       = 'Compiler Driven Development for Ruby <-> OpenAPI 3.2.0'
  spec.description   = 'AST-based bidirectional compiler to convert Ruby code to OpenAPI specs and vice versa ' \
                       'using only the Ruby standard library.'
  spec.homepage      = 'https://github.com/offscale/cdd-ruby'
  spec.licenses      = ['MIT', 'Apache-2.0']

  spec.files         = Dir.glob('src/**/*') + Dir.glob('bin/**/*') + %w[README.md]
  spec.bindir        = 'bin'
  spec.executables   = ['cdd-ruby']
  spec.require_paths = ['src']

  spec.required_ruby_version = '>= 3.0.0'
  spec.add_dependency 'bigdecimal', '>= 3.0'
  spec.add_dependency 'webrick', '~> 1.8'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
