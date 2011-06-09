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
      url = "<b>#{parts[0]}</b>/#{parts[1]}/#{parts[2]}/.../#{parts.last}"
    end
    url
  end
end

get "/" do
  query = params[:s]
  if query and query.strip != ""
    index = Search.new()
    @results = index.get_search_results(query)
  end
  haml :search
end