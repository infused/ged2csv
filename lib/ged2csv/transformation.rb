# encoding: utf-8

module Ged2Csv
  module Transformation
    class DelimitedFile
      cattr_accessor :record_delimiter
      @@record_delimiter = ','
      
      def initialize
        yield self if block_given?
      end
      
    end
  end
end