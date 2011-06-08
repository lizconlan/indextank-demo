require 'nokogiri'
require 'rest-client'
require 'date'

class Parser
  attr_reader :date, :doc_id, :house
  
  def initialize(date, house="Commons")
    @date = date
    @house = house
    @doc_id = "#{date}_hansard_#{house[0..0].downcase()}"
  end
  
  def get_section_links
    parse_date = Date.parse(date)
    index_page = "http://www.parliament.uk/business/publications/hansard/#{house.downcase()}/by-date/?d=#{parse_date.day}&m=#{parse_date.month}&y=#{parse_date.year}"
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