# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rrschedule/version'

Gem::Specification.new do |spec|
  spec.name          = "RRSchedule"
  spec.version       = RRSchedule::VERSION
  spec.authors       = [ "François Lamontagne", "Florent Monbillard", "Will Langstroth" ]
  spec.email         = [ "f.monbillard@gmail.com" ]

  spec.summary       = "Round-Robin Schedule Generator"
  spec.description   = <<-EOF 
  RRSchedule makes it easier to generate round-robin schedules for sports leagues.

  It takes into consideration the number of available fields and different game times and split games into gamedays that respect these contraints.
  EOF
  spec.homepage      = "https://github.com/EppO/rrschedule"
  spec.license       = "MIT"
  
  # This gem will work only with ruby 2.0+ 
  spec.required_ruby_version = '>= 2.0'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = [ "lib" ]

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end