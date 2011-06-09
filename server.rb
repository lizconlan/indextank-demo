require 'sinatra'
require 'lib/test'

get "/" do
  query = params[:s]
  if query and query.strip != ""
    index = Search.new()
    @results = index.get_search_results(query)
  end
  
  haml :search
end