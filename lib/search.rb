require 'indextank'
require 'yaml'

require 'models/catalogue'

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
    @cat = Catalogue.new()
  end
    
  def search(query, filter={}, offset=0)
    # adapted from reddit codebase
    special_characters = [" - ", '&', '|', '(', ')', '{', '}', '[', ']', '^', '"', '~', '*', '?', '\\']
    special_characters.each do |thing_that_crashes_indextank|
      query = query.gsub(thing_that_crashes_indextank, " ").squeeze(" ")
    end
    
    if filter[:member]
      contribs_index.search(query, :snippet => 'text', :fetch => 'title,url,part,volume,columns,chair,section,house,timestamp', 
        :category_filters => filter, :start => offset
      )
    else
      index.search(query, :snippet => 'text', :fetch => 'title,url,part,volume,columns,chair,section,house,timestamp', 
        :category_filters => filter, :start => offset
      )
    end
  end
  
  def add_document(doc_id, doc, text, categories, index_name="idx")
    store = @client.indexes(index_name)
  
    if text
      #add date and section data to Mongo if it's not already there
      if @cat.find('{"pubdate":"' + doc_id[0..9].gsub("-", "/") + '", "section":"' + categories["section"] + '"}') == []
        @cat.add({"pubdate" => doc_id[0..9].gsub("-", "/"), "section" => categories["section"]})
      end
      
      if text.length < 100000  
        doc[:text] = text
                
        store.document(doc_id).add(doc)
        store.document(doc_id).update_categories(categories)
        store.document(doc_id).update_variables({ 0 => doc["timestamp"].to_i})
        p "stored #{doc_id}"
      else
        segment_end = find_breakpoint(text, 100000)
        doc[:text] = text[0..segment_end]
        store.document(doc_id).add(doc)
        store.document(doc_id).update_categories(categories)
        store.document(doc_id).update_variables({ 0 => doc["timestamp"].to_i})
        p "stored #{doc_id}"
        
        text = text[segment_end+1..text.length]
        count = 1
        while text and text.length > 0
          segment_end = find_breakpoint(text, 100000)
          doc[:text] = text[0..segment_end]
          segment_id = "#{doc_id}__#{count}"
          
          store.document(segment_id).add(doc)
          store.document(segment_id).update_categories(categories)
          store.document(doc_id).update_variables({ 0 => doc["timestamp"].to_i})
          p "stored #{segment_id}"
        
          text = text[segment_end+1..text.length]
          count += 1
        end
      end
    end
  end
  
  def add_member(name, post=nil)
    if name.downcase() =~ /^the / or name.downcase() =~ / speaker$/
      if @cat.find_member("{ post : '#{name}' }") == []
        @cat.add_member({"post" => name})
      end
    else
      if name.split(" ").length > 1      
        if @cat.find_member("{ name : '#{name}' }") == []
          @cat.add_member({"name" => name})
        end
      end
    end
    if post and post.length > 0
      if @cat.find_member("{ post : '#{post}' }") == []
        @cat.add_member({"post" => post})
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