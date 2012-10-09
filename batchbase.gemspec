# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "batchbase/version"

Gem::Specification.new do |s|
  s.name        = "batchbase"
  s.version     = Batchbase::VERSION
  s.authors     = ["pacojp"]
  s.email       = ["paco.jp@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{oreore batch base class}
  s.description = %q{oreore batch base class}
  s.rubyforge_project = "batchbase"

  s.add_dependency "sys-proctable","0.9.1"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
end
