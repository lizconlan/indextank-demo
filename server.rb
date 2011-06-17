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
  if @query and @query.strip != ""
    offset = @query.index("member:")
    member = nil
    if offset
      string_end = @query.index(" ", offset+7)
      string_end = @query.length unless string_end 
      member = @query[offset+7..string_end].strip
      @query = @query.gsub("member:#{member}", "").strip
    end
    
    @filter = {}
    index = Search.new()
    if params[:cat] and params[:val] and params[:cat].strip != "" and params[:val].strip != ""
      @filter[params[:cat]] = params[:val]
    end
    if member
      @filter[:member] = member.gsub("+", " ")
    end
    @results = index.search(@query, @filter)
    
    @facets = @results["facets"]
    # "search_time"=>"0.046", "facets"=>{"section"=>{"Debates and Oral Answers"=>6}, "house"=>{"Commons"=>6}, "source"=>{"Hansard"=>6}}, "matches"=>6
  end
  haml :search
end