require 'test_helper'

class Ged2csvTest < Test::Unit::TestCase
  def setup
    # Default options
    # 
    # @transformation = Ged2Csv::Transformation::DelimitedFile do |t|
    #   t.record_delimiter = ','
    #   t.quote_character = '"'
    #   t.paragraph_seperator = "<br>"
    #   t.wrap_notes = '72'
    #   t.output_directory = './'
    #   t.citation_filename = '' = 'citation_list.txt'
    #   t.fact_filename = 'fact_list.txt'
    #   t.family_filename = 'family_list.txt'
    #   t.individual_filename = 'individual_list.txt'
    #   t.note_filename = 'note_list.txt'
    #   t.relationship_filename = 'relationship_list.txt'
    #   t.source_filename = 'source_list.txt'
    # end
    
    @transformation = Ged2Csv::Transformation::DelimitedFile.new
  end
  
  should 'initialize a new transformation' do
    assert_kind_of Ged2Csv::Transformation::DelimitedFile, @transformation
  end
  
  context 'when initialized' do
    should 'default the record_delimiter to a comma' do
      assert_equal ',', @transformation.record_delimiter
    end
    
    should 'default the quote_character to a double-quote'
    should 'default the paragraph_seperator to <br>'
    should 'default the wrap_notes to 72'
    should 'default the output_directory to "./"'
    should 'have a default the citation_filename'
    should 'have a default the fact_filename'
    should 'have a default the family_filename'
    should 'have a default the individual_filename'
    should 'have a default the note_filename'
    should 'have a default the relationship_filename'
    should 'have a default the source_filename'
    
    should 'override the default record_delimiter' do
      @transformation.record_delimiter = '|'
      assert_equal '|', @transformation.record_delimiter
    end
    
    should 'override the default record_delimiter from a block' do
      transformation = Ged2Csv::Transformation::DelimitedFile.new do |t|
        t.record_delimiter = ':'
      end
      
      assert_equal ':', transformation.record_delimiter
    end
  end
end
