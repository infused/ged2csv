require 'spec_helper'

describe Ged2Csv do
  before do
    @transformation = Ged2Csv::Transformation::DelimitedFile.new
  end
  
  describe 'when initialized' do
    it 'should initialize a new transformation' do
      @transformation.should be_kind_of(Ged2Csv::Transformation::DelimitedFile)
    end
    
    it 'defaults the record_delimiter to a comma' do
      @transformation.record_delimiter.should == ','
    end
    
    it 'defaults the quote_character to a double-quote'
    it 'defaults the paragraph_seperator to <br>'
    it 'defaults wrap_notes to 72'
    it 'defaults the output_directory to "./"'
    it 'should have a default citation_filename'
    it 'should have a default the fact_filename'
    it 'should have a default the family_filename'
    it 'should have a default the individual_filename'
    it 'should have a default the note_filename'
    it 'should have a default the relationship_filename'
    it 'should have a default the source_filename'
    
    it 'allows overriding the default record_delimiter' do
      @transformation.record_delimiter = '|'
      @transformation.record_delimiter.should == '|'
    end
    
    it 'allos overriding the default record_delimiter within a block' do
      transformation = Ged2Csv::Transformation::DelimitedFile.new do |t|
        t.record_delimiter = ':'
      end
      
      transformation.record_delimiter.should == ':'
    end
  end
end