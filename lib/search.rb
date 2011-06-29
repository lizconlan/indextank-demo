require 'rubygems'
require 'indextank'
require 'yaml'

class Search
  attr_reader :index, :contribs_index
  
  def initialize
    indextank_url = ""
    if ENV['RACK_ENV'] && ENV['RACK_ENV'] == 'production' #heroku
      indextank_url = ENV['indextank_url']
    else
      yql_conf = YAML.load(File.read('config/indextank.yml'))      
      indextank_url = yql_conf[:private_url]
    end
    
    @client = IndexTank::Client.new(indextank_url)
    @index = @client.indexes('idx')
    @contribs_index = @client.indexes('contributions')
  end
    
  def search(query, filter={})
    # adapted from reddit codebase
    # we may use ':' for something specific later
    special_characters = ['+', "'", '-', '&', '|', '!', '(', ')', '{', '}', '[', ']', '^', '"', '~', '*', '?', ':', '\\']
    special_characters.each do |thing_that_crashes_indextank|
      query = query.gsub(thing_that_crashes_indextank, "")
    end
    
    if filter[:member]
      contribs_index.search(query, :snippet => 'text', :fetch => 'title,url,part,volume,columns,chair,section,house,timestamp', 
        :category_filters => filter
      )
    else
      index.search(query, :snippet => 'text', :fetch => 'title,url,part,volume,columns,chair,section,house,timestamp', 
        :category_filters => filter
      )
    end
  end
  
  def add_document(doc_id, doc, text, categories, index_name="idx")
    store = @client.indexes(index_name)
  
    if text
      if text.length < 100000
        doc[:text] = text
        store.document(doc_id).add(doc)
        store.document(doc_id).update_categories(categories)
        p "stored #{doc_id}"
      else
        segment_end = find_breakpoint(text, 100000)
        doc[:text] = text[0..segment_end]
        store.document(doc_id).add(doc)
        store.document(doc_id).update_categories(categories)
        p "stored #{doc_id}"
        
        text = text[segment_end+1..text.length]
        count = 1
        while text and text.length > 0
          segment_end = find_breakpoint(text, 100000)
          doc[:text] = text[0..segment_end]
          segment_id = "#{doc_id}__#{count}"
        
          store.document(segment_id).add(doc)
          store.document(segment_id).update_categories(categories)
          p "stored #{segment_id}"
        
          text = text[segment_end+1..text.length]
          count += 1
        end
      end
    end
  end
  
  private
    def find_breakpoint(text, bound)
      sentence_terminators = [".", "!", "?"]
      
      unless text.length > bound
        return bound
      end
      
      while !(sentence_terminators.include?(text[bound..bound]))
        bound -=1
      end
      bound
    end
end