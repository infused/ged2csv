# encoding: utf-8

lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
require 'ged2csv/version'

Gem::Specification.new do |s|
  s.name = 'ged2csv'
  s.version = Ged2Csv::VERSION
  s.authors = ["Keith Morrison"]
  s.email = %q{keithm@infused.org}
  s.homepage = 'http://github.com/infused/ged2csv'
  s.summary = 'ged2csv'

  s.rdoc_options = ['--charset=UTF-8']
  s.extra_rdoc_files = ['README.rdoc', 'LICENSE']
  s.files = Dir['[A-Z]*', '{docs,lib,spec}/**/*']
  s.test_files = Dir.glob('spec/**/*_spec.rb')
  s.require_paths = ['lib']

  s.required_rubygems_version = '>= 1.3.0'
  s.add_dependency 'ansel_iconv', '~> 1.1.6'
  s.add_development_dependency 'rspec', '~> 2.3.0'
end
