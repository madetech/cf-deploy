lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cf/deploy/version'

Gem::Specification.new do |spec|
  spec.name          = 'cf-deploy'
  spec.version       = Cf::Deploy::VERSION
  spec.authors       = ['Luke Morton']
  spec.email         = ['luke@madebymade.co.uk']
  spec.summary       = %q{Rake tasks for deploying to CloudFoundry v6+}
  spec.homepage      = 'https://github.com/madebymade/cf-deploy'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split('\x0')
  spec.test_files    = ['spec']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_development_dependency 'rake'
end
