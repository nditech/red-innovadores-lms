# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "adheres_to_policy"
  spec.version       = '0.0.1'
  spec.authors       = ["Raphael Weiner", "Stephan Hagemann"]
  spec.email         = ["rweiner@pivotallabs.com", "stephan@pivotallabs.com"]
  spec.summary       = %q{The canvas adheres to policy gem}

  spec.files         = Dir.glob("{lib,spec}/**/*") + %w(Rakefile README.md test.sh)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'rails', '~>3.2'

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "2.99.0"
end
