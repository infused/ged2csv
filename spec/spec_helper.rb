# encoding: utf-8

$:.unshift(File.dirname(__FILE__) + '/../lib/')
require 'rubygems'
require 'rspec'
require 'ged2csv'

DB_PATH = File.dirname(__FILE__) + '/fixtures' unless defined?(DB_PATH)

RSpec.configure do |config|
  
end
