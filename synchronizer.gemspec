# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "synchronizer"
  s.version     = "0.0.1"
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
  s.add_dependency "builder","~> 3.0.0"
  s.add_dependency "i18n","0.6.11"
  s.add_dependency "httparty","0.11"
  s.add_dependency "hashie"
  s.add_dependency "json"
  s.add_dependency "ext"
  s.add_dependency "gli","1.6.0"
  s.add_dependency "attask"
  s.add_dependency "logger"
  s.add_dependency "pony"
  s.add_dependency "rforce","=0.11"
  s.add_dependency "chronic"
  s.add_dependency "fastercsv"
  s.add_dependency "aws-s3"
  s.add_dependency "activesupport","3.2.16"
  s.add_dependency 'databasedotcom',"1.0.7"
  s.add_dependency 'mime-types',"1.24"
  s.add_dependency 'nokogiri',"1.5.5"


end
