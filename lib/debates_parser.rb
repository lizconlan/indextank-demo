require 'lib/parser'

class DebatesParser < Parser
  def get_section_index
    url = get_section_links["Debates and Oral Answers"]
    if url
      response = RestClient.get(url)
      return response.body
    end
  end
  
  def link_to_first_page
    html = get_section_index
    return nil unless html
    doc = Nokogiri::HTML(html)
    
    relative_path = doc.xpath("//div[@id='content-small']/p[3]/a").attr("href").value.to_s
    "http://www.publications.parliament.uk#{relative_path[0..relative_path.rindex("#")-1]}"
  end
end