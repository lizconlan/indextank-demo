require 'lib/parser'

class DebatesParser < Parser  
  def initialize
    super()
    @start_column, @end_column, @volume, @part = nil
  end
  
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
  
  def parse_pages
    page = Page.new(link_to_first_page)
    parse_page(page)
    if page.next_url
      page = Page.new(page.next_url)
      parse_page(page.next_url)
    end
  end
  
  def parse_page(page)
    subject = page.doc.xpath("//meta[@name='Subject']").attr("content").value.to_s
    column_range = page.doc.xpath("//meta[@name='Columns']").attr("content").value.to_s
    cols = column_range.gsub("Columns: ", "").split(" to ")
    
    @start_column = cols[0]
    @end_column = cols[1]
    @volume = subject[subject.index("Volume:")+8..subject.rindex(",")-1]
    @part = subject[subject.index("Part:")+6..subject.length]
    
    content = page.doc.xpath("//div[@id='content-small']")
  end
end