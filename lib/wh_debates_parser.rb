require 'lib/parser'
require 'lib/page'
require 'lib/test'

class WHDebatesParser < Parser
  attr_reader :section
  
  def initialize(date, house="Commons", section="Westminster Hall")
    super(date, house)
    @section = section
  end
  
  def get_section_index
    url = get_section_links[section]
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
    @column = ""
    @page = 0
    @count = 0
    
    @snippet_type = ""
    @last_link = ""
    @snippet = []
    @questions = []
    @subject = ""
    @start_column = ""
    @end_column = ""
    @chair = ""
    
    page = Page.new(link_to_first_page)
    parse_page(page)
    while page.next_url
      page = Page.new(page.next_url)
      parse_page(page)
    end
    
    #flush the buffer
    unless @snippet.empty?
      write_segment(page)
      @snippet = []
    end
  end
  
  def parse_page(page)    
    @page += 1
    content = page.doc.xpath("//div[@id='content-small']")
    content.children.each do |child|
      if child.class == Nokogiri::XML::Element
        parse_node(child, page)
      end
    end
  end
  
  private
    def parse_node(node, page)
      case node.name
        when "a"
          @last_link = node.attr("name")
          if node.attr("class") == "anchor-column"
            if @start_column == ""
              @start_column = node.attr("name").gsub("column_", "")
            else
              @end_column = node.attr("name").gsub("column_", "")
            end
            @snippet_type = "column heading"
          else
            case node.attr("name")
              when /^time_/
                @snippet_type = "timestamp"
              when /^place_/
                @snippet_type = "location heading"
              when /^hd_/
                @snippet_type = "heading"
              when /^st_/
                @snippet_type = "contribution"
            end
          end
        when "h3"
          unless @snippet.empty?
            write_segment(page)
            @snippet = []
            @segment_link = ""
          end
          text = node.text.gsub("\n", "").squeeze(" ").strip
          @snippet << sanitize_text(text)
          @subject = sanitize_text(text)
          @segment_link = "#{page.url}\##{@last_link}"
        when "h4"
          text = node.text.gsub("\n", "").squeeze(" ").strip
          if text[text.length-13..text.length-2] == "in the Chair"
            @chair = text[1..text.length-15]
          end
        when "p"
          text = node.text.gsub("\n", "").squeeze(" ").strip
          unless text =~ /^\d+ [A-Z][a-z]+ \d{4} : Column \d+(WH)?$/
            @snippet << sanitize_text(text)
          end
      end
    end
    
    def write_segment(page)
      s = Search.new()
      segment_id = "#{doc_id}_wh_#{@count}"
      @count += 1
      s.index.document(segment_id).add(
        {:title => sanitize_text("Westminster Hall Debate - #{@subject}"),
         :text => @snippet.join(" "),
         :volume => page.volume,
         :columns => "#{@start_column} to #{@end_column}",
         :part => sanitize_text(page.part.to_s),
         :chair => @chair,
         :subject => @subject,
         :url => @segment_link,
         :house => house,
         :section => section,
         :timestamp => Time.parse(date).to_i
        }
      )

      categories = {"house" => house, "source" => "Hansard", "section" => section}
      s.index.document(segment_id).update_categories(categories)

      p @subject
      p segment_id
      p ""
    end
end