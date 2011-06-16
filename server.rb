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
end

get "/" do
  query = params[:q]
  if query and query.strip != ""
    index = Search.new()
    if params[:cat] and params[:val] and params[:cat].strip != "" and params[:val].strip != ""
      @filter = {params[:cat] => params[:val]}
      @results = index.get_search_results(query, @filter)
    else
      @results = index.get_search_results(query)
    end
    
    @facets = @results["facets"]
    # "search_time"=>"0.046", "facets"=>{"section"=>{"Debates and Oral Answers"=>6}, "house"=>{"Commons"=>6}, "source"=>{"Hansard"=>6}}, "matches"=>6
  end
  haml :search
end
