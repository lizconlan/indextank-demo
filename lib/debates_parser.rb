require 'lib/parser'
require 'lib/page'
require 'lib/search'

class DebatesParser < Parser
  attr_reader :section
  
  def initialize(date, house="Commons", section="Debates and Oral Answers")
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
    
    page = Page.new(link_to_first_page)
    parse_page(page)
    while page.next_url
      page = Page.new(page.next_url)
      parse_page(page)
    end
  end
  
  def parse_page(page)
    @snippet_type = ""
    @link = ""
    @topics = []
    @departments = []
    @snippet = []
    @speakers = []
    @snippets = []
    @questions = []
    
    @page += 1
    content = page.doc.xpath("//div[@id='content-small']")
    content.children.each do |child|
      if child.class == Nokogiri::XML::Element
        parse_node(child)
      end
    end
    
    s = Search.new()
    segment_id = "#{doc_id}_#{section.downcase().gsub(" ", "-")}_#{@page}"
    s.index.document(segment_id).add(
      {:title => sanitize_text(page.title),
       :text => @snippets.join(" "),
       :volume => page.volume,
       :columns => "#{page.start_column} to #{page.end_column}",
       :part => sanitize_text(page.part.to_s),
       :url => page.url,
       :house => house,
       :section => section,
       :timestamp => Time.parse(date).to_i
      }
    )
    
    categories = {"house" => house, "source" => "Hansard", "section" => section}
    s.index.document(segment_id).update_categories(categories)
    
    p segment_id
  end
  
  private
    def parse_node(node)
      case node.name
        when "a"
          if node.attr("class") == "anchor-column"
            @column = node.attr("name").gsub("column_", "")
            @link = node.attr("name")
            @snippet_type = "column heading"
          else
            unless @snippet == []
              @snippets << @snippet.join(" ")
              @snippet = []
            end
            case node.attr("name")
              when /^hd_/
                #heading e.g. the date, The House met at..., The Deputy PM was asked
                @snippet_type = "heading"
                @link = node.attr("name")
              when /^place_/
                @snippet_type = "location heading"
                @link = node.attr("name")
              when /^oralhd_/
                @snippet_type = "question heading"
                @link = node.attr("name")
              when /^depthd_/
                @snippet_type = "department heading"
                @link = node.attr("name")
              when /^subhd_/
                @snippet_type = "subheading" #if we're lucky it's a topic
                @link = node.attr("name")
              when /^qn_/
                @snippet_type = "question"
                @link = node.attr("name")
              when /^st_/
                @snippet_type = "contribution"
                @link = node.attr("name")
            end
          end
        when "h2"
          text = node.text.gsub("\n", "").squeeze(" ").strip
          @snippet << sanitize_text(text)
        when "h3"
          text = node.text.gsub("\n", "").squeeze(" ").strip
          @snippet << sanitize_text(text)
          if @snippet_type == "department heading"
            @departments << sanitize_text(text)
          end
          if @snippet_type == "question heading"
            @topics << sanitize_text(text)
          end
        when "h4"
          text = node.text.gsub("\n", "").squeeze(" ").strip
          @snippet << sanitize_text(text)
        when "h5"
          text = node.text.gsub("\n", "").squeeze(" ").strip
          @snippet << sanitize_text(text)
        when "p"
          unless @snippet_type == "column heading"
            text = node.text.gsub("\n", "").squeeze(" ").strip
            @snippet << sanitize_text(text)
            if @snippet_type == "question" and text[text.length-1..text.length] == "]"
              question = text[text.rindex("[")+1..text.length-2]
              @questions << sanitize_text(question)
            end
          end
        when "div"
         #if node.attr("class").value.to_s == "navLinks"
         #ignore
        when "hr"
          #ignore
      end
    end
end
