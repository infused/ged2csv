# encoding: utf-8

module Ged2Csv
  module Transformation
    class DelimitedFile
      attr_accessor :record_delimiter
      
      def initialize
        @record_delimiter = ','
        
        yield self if block_given?
      end
      
    end
  end
end