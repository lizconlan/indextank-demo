require 'nokogiri'
require 'rest-client'

class Page
  attr_reader :html, :doc, :url, :next_url
  
  def initialize(url)
    @url = url
    response = RestClient.get(url)
    @html = response.body
    @doc = Nokogiri::HTML(@html)
    next_link = @doc.xpath("//div[@class='navLinks'][2]/div[@class='navLeft']/a")
    unless next_link.empty?
      prefix = url[0..url.rindex("/")]
      @next_url = prefix + next_link.attr("href").value.to_s
    else
      @next_url = nil
    end
  end
end