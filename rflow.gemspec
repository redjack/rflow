# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "rflow/version"

Gem::Specification.new do |s|
  s.name        = "rflow"
  s.version     = RFlow::VERSION
  s.platform    = Gem::Platform::RUBY
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

  s.add_dependency 'avro', '>= 1.3.3'
  s.add_dependency 'zmq' , '>= 2.1.0.1'
    
  s.add_development_dependency 'rspec', '>= 2.5.0'
end
