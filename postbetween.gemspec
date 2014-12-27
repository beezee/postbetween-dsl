# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'postbetween/version'

Gem::Specification.new do |spec|
  spec.name          = "postbetween"
  spec.version       = Postbetween::VERSION
  spec.authors       = ["Brian Zeligson"]
  spec.email         = ["bzeligson@localytics.com"]
  spec.summary       = "DSL and server for transforming and forwarding incoming postback requests"
  spec.description   = ""
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_runtime_dependency "functional-ruby"
  spec.add_runtime_dependency "deterministic"
  spec.add_runtime_dependency "sinatra"
  spec.add_runtime_dependency "activesupport"
end
