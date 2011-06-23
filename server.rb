require 'sinatra'
require 'lib/test'

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
end

get "/favicon.ico" do
  status 404
end

get "/" do
  @query = params[:q]
  @suggestions = []
  
  @filter = {}
  
  if params[:cat] and params[:val] and params[:cat].strip != "" and params[:val].strip != ""
    @filter[params[:cat]] = params[:val]
  end
  
  if @query and @query.strip != ""
    offset = @query.index("member:")
    @member = nil
    if offset
      string_end = @query.index(" ", offset+7)
      string_end = @query.length unless string_end 
      @member = @query[offset+7..string_end].strip
      @query = @query.gsub("member:#{@member}", "").strip
    end
    
    if @member
      @results = do_member_debates_search(@member, @query)
      if @results["matches"] == 0 and @query == ""
        surname = @member.split("+").last
        firstname = @member.split("+").first
        results = do_member_contributions_search(surname)
        candidates = results["facets"]["member"]
        if candidates
          candidates.each do |candidate_name, count|
            if candidate_name.split(" ").first == firstname
              @suggestions << candidate_name
            end
          end
          if @suggestions.empty?
            @suggestions = candidates.collect{ |x| x[0] }
          end
        end
        p @suggestions
      end
    else
      index = Search.new()
      @results = index.search(@query, @filter)
    end
    
    @facets = @results["facets"]
    # "search_time"=>"0.046", "facets"=>{"section"=>{"Debates and Oral Answers"=>6}, "house"=>{"Commons"=>6}, "source"=>{"Hansard"=>6}}, "matches"=>6
  end
  haml :search
end

private
  def do_member_debates_search(member_name, rest_of_query="")
    search = Search.new()
    query = "members:#{member_name}"
    query = "#{query} text:#{rest_of_query}" unless rest_of_query == ""
    search.index.search(query, :snippet => 'text', :fetch => 'title,url,part,volume,columns,chair,section,house',
       :category_filters => @filter)
  end
  
  def do_member_contributions_search(member_name)
    search = Search.new()
    query = "member:#{member_name}"
    search.contribs_index.search(query)
  end