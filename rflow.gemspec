# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "rflow/version"

Gem::Specification.new do |s|
  s.name        = "rflow"
  s.version     = RFlow::VERSION
  s.platform    = Gem::Platform::RUBY
  s.required_ruby_version = '1.9.2'
  s.authors     = ["Michael L. Artz"]
  s.email       = ["michael.artz@redjack.com"]
  s.homepage    = ""
  s.summary     = %q{A Ruby-based workflow framework}
  s.description = %q{A Ruby-based workflow framework that utilizes ZeroMQ for computation connections and Avro for serialization}

  s.rubyforge_project = "rflow"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'uuidtools', '= 2.1.2'
  s.add_dependency 'log4r', '= 1.1.9'
  
  s.add_dependency 'sqlite3', '= 1.3.3'
  s.add_dependency 'activerecord', '= 3.0.7'
  
  s.add_dependency 'avro', '>= 1.3.3'
  s.add_dependency 'ffi', '= 1.0.7'
  s.add_dependency 'ffi-rzmq' , '= 0.8.0'
  
  s.add_development_dependency 'rspec', '= 2.5.0'
  s.add_development_dependency 'rake', '= 0.8.7'
  #s.add_development_dependency 'rcov', '= 0.9.9' # Not 1.9.2 compatible
end
