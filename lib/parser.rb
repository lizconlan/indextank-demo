require 'nokogiri'
require 'rest-client'
require 'date'
require 'time'

class Parser
  attr_reader :date, :doc_id, :house
  
  COLUMN_HEADER = /^\d+ [A-Z][a-z]+ \d{4} : Column (\d+(?:WH)?(?:WS)?(?:P)?(?:W))(?:-continued)?$/
  
  def initialize(date, house="Commons")
    @date = date
    @house = house
    @doc_id = "#{date}_hansard_#{house[0..0].downcase()}"
  end
  
  def get_section_index(section)
    url = get_section_links[section]
    if url
      response = RestClient.get(url)
      return response.body
    end
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
  
  def link_to_first_page
    html = get_section_index
    return nil unless html
    doc = Nokogiri::HTML(html)
    
    content_section = doc.xpath("//div[@id='content-small']/p[3]/a")
    if content_section.empty?
      content_section = doc.xpath("//div[@id='maincontent1']/div/a[1]")
    end
    relative_path = content_section.attr("href").value.to_s
    "http://www.publications.parliament.uk#{relative_path[0..relative_path.rindex("#")-1]}"
  end
  
  def parse_page(page)    
    @page += 1
    content = page.doc.xpath("//div[@id='content-small']")
    if content.empty?
      content = page.doc.xpath("//div[@id='maincontent1']")
    end
    content.children.each do |child|
      if child.class == Nokogiri::XML::Element
        parse_node(child, page)
      end
    end
  end
  
  private
    def sanitize_text(text)
      text = text.gsub("\342\200\230", "'")
      text = text.gsub("\342\200\231", "'")
      text = text.gsub("\342\200\234", '"')
      text = text.gsub("\342\200\235", '"')
      text = text.gsub("\342\200\224", " - ")
      text = text.gsub("\302\243", "£")
      text
    end
end
