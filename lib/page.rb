require 'nokogiri'
require 'rest-client'

class Page
  attr_reader :html, :doc, :next_page
  
  def initialize(url)
    response = RestClient.get(url)
    @html = response.body
    @doc = Nokogiri::HTML(@html)
    next_link = @doc.xpath("//div[@class='navLinks'][2]/div[@class='navLeft']/a")
    unless next_link.empty?
      prefix = url[0..url.rindex("/")]
      @next_page = prefix + next_link.attr("href").value.to_s
    else
      @next_page = nil
    end
  end
end