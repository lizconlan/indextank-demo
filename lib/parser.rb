require 'nokogiri'
require 'rest-client'

class Parser
  attr_reader :date
  
  def initialize(date)
    @date = date
  end
  
  def get_section_links
    parse_date = Date.parse(date)
    index_page = "http://www.parliament.uk/business/publications/hansard/commons/by-date/?d=#{parse_date.day}&m=#{parse_date.month}&y=#{parse_date.year}"
    begin
      result = RestClient.get(index_page)
    rescue
      return nil
    end
  
    doc = Nokogiri::HTML(result.body)
    urls = Hash.new
  
    doc.xpath("//ul[@id='publication-items']/li/a").each do |link|
      urls["#{link.text.strip}"] = link.attribute("href").value.to_s
    end
  
    urls
  end
end