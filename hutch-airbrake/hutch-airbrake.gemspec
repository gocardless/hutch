require File.expand_path('../../lib/hutch/version', __FILE__)

Gem::Specification.new do |gem|
  gem.add_runtime_dependency 'hutch', Hutch::VERSION
  gem.add_runtime_dependency 'airbrake', '~>4.0'

  gem.name = 'hutch-airbrake'
  gem.summary = 'Easy inter-service communication using RabbitMQ.'
  gem.description = 'Hutch is a Ruby library for enabling asynchronous ' +
                    'inter-service communication using RabbitMQ.'
  gem.version = Hutch::VERSION.dup
  gem.authors = ['Harry Marr']
  gem.email = ['developers@gocardless.com']
  gem.homepage = 'https://github.com/gocardless/hutch'
  gem.require_paths = ['lib']
  gem.license = 'MIT'
  gem.files = Dir.glob("lib/**/*")
  gem.test_files = Dir.glob("spec/**/*")
end
