# encoding: utf-8

module Ged2Csv
  module Transformation
    class DelimitedFile
      attr_accessor :record_delimiter
      attr_accessor :quote_character
      attr_accessor :paragraph_separator
      attr_accessor :wrap_notes
      
      def initialize
        @record_delimiter = ','
        @quote_character = '"'
        @paragraph_separator = '<br />'
        @wrap_notes = 72
        
        yield self if block_given?
      end
      
    end
  end
end