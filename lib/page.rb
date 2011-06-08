require 'nokogiri'
require 'rest-client'

class Page
  attr_reader :html, :doc, :url, :next_url, :start_column, :end_column, :volume, :part
  
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
    scrape_metadata()
  end
  
  private
    def scrape_metadata
      subject = doc.xpath("//meta[@name='Subject']").attr("content").value.to_s
      column_range = doc.xpath("//meta[@name='Columns']").attr("content").value.to_s
      cols = column_range.gsub("Columns: ", "").split(" to ")

      @start_column = cols[0]
      @end_column = cols[1]
      @volume = subject[subject.index("Volume:")+8..subject.rindex(",")-1]
      @part = subject[subject.index("Part:")+6..subject.length]
    end
end