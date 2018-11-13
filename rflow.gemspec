lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rflow/version'

Gem::Specification.new do |s|
  s.name        = 'rflow'
  s.version     = RFlow::VERSION
  s.platform    = Gem::Platform::RUBY
  s.required_ruby_version = '>= 1.9'
  s.authors     = ['John Stoneham', 'Michael L. Artz']
  s.email       = ['john.stoneham@redjack.com', 'mlartz@gmail.com']
  s.homepage    = 'https://github.com/redjack/rflow'
  s.license     = 'Apache-2.0'
  s.summary     = %q{A Ruby flow-based programming framework}
  s.description = %q{A Ruby flow-based programming framework that utilizes ZeroMQ for component connections and Avro for serialization}

  s.files         = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']
  s.bindir        = 'bin'

  s.add_dependency 'uuidtools', '~> 2.1'
  s.add_dependency 'log4r', '~> 1.1'
  s.add_dependency 'sys-filesystem', '~> 1.1'

  s.add_dependency 'sqlite3', '~> 1.3'
  s.add_dependency 'activerecord', '~> 4.0'

  s.add_dependency 'avro', '~> 1.8'
  s.add_dependency 'avro-patches', '~> 0.4' # update patches to official avro
  s.add_dependency 'em-zeromq', '~> 0.5'

  s.add_development_dependency 'bundler', '~> 1.0'
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rspec-collection_matchers', '~> 1.0'
  s.add_development_dependency 'rake', '>= 10.3'
  s.add_development_dependency 'yard', '~> 0.9'
end
