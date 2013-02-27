# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "version"

Gem::Specification.new do |s|
  s.name        = "synchronizer"
  s.version     = Synchronizer::VERSION
  s.authors     = ["Adrian Toman"]
  s.email       = ["adrian.toman@gmail.com"]
  s.homepage    = ""
  s.summary     = "Synchronizer from SFDC to AtTask API"
  s.description = ""

  s.rubyforge_project = "attask"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_dependency "httparty"
  s.add_dependency "hashie"
  s.add_dependency "json"
  s.add_dependency "ext"
  s.add_dependency "gli"
  s.add_dependency "attask"
  s.add_dependency "logger"
  s.add_dependency "pony"
  s.add_dependency "rforce"


end
