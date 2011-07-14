require 'sinatra'
require 'time'
require 'lib/search'

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
  
  def format_url(url)
    url = url[url.index("//")+2..url.length]
    if url.rindex("#") and url.rindex("/") and url.rindex("#") > url.rindex("/")
      url = url[0..url.rindex("#")-1]
    end
    if url.length > 50
      parts = url.split("/")
      url = "<strong class='highlight'>#{parts[0]}</strong>/#{parts[1]}/#{parts[2]}/&hellip;/#{parts.last}"
    end
    url
  end
  
  def display_section(section, chair="")
    case section
      when "Westminster Hall"
        "<strong>Westminster Hall</strong> &mdash; #{chair} in the Chair"
      else
        "<strong>#{section}</strong>"
    end
  end
  
  def display_time(timestamp)
    Time.at(timestamp.to_i + 7200).utc.strftime("%d %b %Y")
  end
end

get "/favicon.ico" do
  status 404
end

get "/style/main.css" do
  sass :"/style/main"
end

get "/" do
  @query = params[:q]
  @page = params[:p].to_i
  @suggestions = []
  
  query = @query
  
  @page = 1 if @page < 1
  
  #the default for IndexTank, can be changed (I think)
  #not currently specified, relying on default value
  @page_size = 10
  
  @start = (@page-1)*@page_size
  
  @filter = {}
  
  if params[:f]
    pairs = params[:f].split("^")
    pairs.each do |pair|
      filter = pair.split("|")
      @filter[filter[0]] = filter[1]
    end
  end
  
  starting_query = @query
  
  if @query and @query.strip != ""
    while @query.index('"')
      offset = @query.index('"')
      string_end = @query.index('"', offset+1)
      if string_end
        string_end -= 1
      else
        string_end = @query.length
      end
      for_replacement = @query[offset+1..string_end]
      if offset > 0
        query = "#{@query[0..offset-1]}#{for_replacement.gsub(" ", "+")}"
      else
        query = for_replacement.gsub(" ", "+")
      end
      if string_end < @query.length
        query = "#{query}#{@query[string_end+2..@query.length]}"
      end
      starting_query = @query = query
    end
    
    offset = @query.index("member:")
    @member = nil
    if offset
      string_end = @query.index(" ", offset+7)
      string_end = @query.length unless string_end 
      @member = @query[offset+7..string_end].strip
      @query = @query.gsub("member:#{@member}", "").strip
      query = "members:#{@member}"
    end
    
    offset = @query.index("question:")
    @question = nil
    if offset
      string_end = @query.index(" ", offset+9)
      string_end = @query.length unless string_end 
      @question = @query[offset+9..string_end].strip
      @query = @query.gsub("question:#{@question}", "").strip
      query = "questions:#{@question}"
    end
    
    offset = @query.index("petition:")
    @petition = nil
    if offset
      string_end = @query.index(" ", offset+9)
      string_end = @query.length unless string_end 
      @petition = @query[offset+9..string_end].strip
      @query = @query.gsub("petition:#{@petition}", "").strip
      query = "petitions:#{@petition}"
    end
    
    unless @query == starting_query
      unless @query.strip == ""
        query = "#{query} text:#{@query}"
      end
    end
    
    index = Search.new()
    @results = index.search(query, @filter, @start)
    
    if @member
      if @results["matches"] == 0 and @query == ""
        surname = @member.split("+").last
        firstname = @member.split("+").first
        results = do_member_contributions_search(surname)
        candidates = results["facets"]["member"]
        if candidates
          candidates.each do |candidate_name, count|
            if candidate_name.split(" ").first.downcase == firstname.downcase
              @suggestions << candidate_name
            end
          end
          if @suggestions.empty?
            @suggestions = candidates.collect{ |x| x[0] }
          end
        end
      end
    end
    
    @results = dedup_results(@results)
    @last_record = @start + @page_size
    if @results["matches"] < @last_record
      @last_record = @results["matches"]
    end
    
    @facets = @results["facets"]
    # "search_time"=>"0.046", "facets"=>{"section"=>{"Debates and Oral Answers"=>6}, "house"=>{"Commons"=>6}, "source"=>{"Hansard"=>6}}, "matches"=>6
  end
  haml :search
end

private  
  def do_member_contributions_search(member_name)
    search = Search.new()
    query = "member:#{member_name}"
    search.contribs_index.search(query, :fetch => 'title,url,part,volume,columns,chair,section,house,timestamp')
  end
  
  def dedup_results(results)
    for_deletion = []
    possible_duplicates = []
    
    all_ids = results["results"].collect { |x| x["docid"] }
    results["results"].each do |result|
      #if there's a continuation result
      if result["docid"] =~ /(__\d+)$/
        suffix = $1
        #...and its parent is also in the result set (or a more relevant sibling has already been found)
        if all_ids.include?(result["docid"].gsub(suffix, "")) or possible_duplicates.include?(result["docid"].gsub(suffix, ""))
          #harvest the facet data
          section = result["section"]
          house = result["house"]
          #flag the duplicate record for deletion
          for_deletion << result["docid"]
          #decrement matches
          results["matches"] -= 1
          #decrement the affected facet scores
          results["facets"]["house"][house] -= 1
          results["facets"]["section"][section] -= 1
        end
        possible_duplicates << result["docid"].gsub(suffix, "")
      end
    end
    #delete the unwanted records (if applicable)
    results["results"].delete_if { |x| for_deletion.include?(x["docid"])}
    results
  end