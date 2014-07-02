lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cf/deploy/version'

Gem::Specification.new do |spec|
  spec.name          = 'cf-deploy'
  spec.version       = CF::Deploy::VERSION
  spec.authors       = ['Luke Morton']
  spec.email         = ['luke@madebymade.co.uk']
  spec.summary       = %q{Rake tasks for deploying to CloudFoundry v6+}
  spec.homepage      = 'https://github.com/madebymade/cf-deploy'
  spec.license       = 'MIT'

  spec.files         = Dir['{lib,spec}/**/*.rb'] + ['LICENSE', 'README.md']
  spec.test_files    = ['spec']
  spec.require_paths = ['lib']

  spec.add_dependency 'rake'

  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_development_dependency 'rspec', '~> 3.0.0'
  spec.add_development_dependency 'simplecov', '~> 0.7.1'
  spec.add_development_dependency 'coveralls', '~> 0.7.0'
end
