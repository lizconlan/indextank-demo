require 'lib/parser'
require 'lib/search'
require 'models/page'
require 'models/member'

class DebatesParser < Parser
  attr_reader :section
  
  def initialize(date, house="Commons", section="Debates and Oral Answers")
    super(date, house)
    @section = section
  end
  
  def get_section_index
    super(section)
  end
  
  def parse_pages
    @column = ""
    @page = 0
    @contribution_count = 0
    
    @members = {}
    @member = nil
    @contribution = nil
    
    @last_link = ""
    @snippet = []
    @subject = ""
    @department = ""
    @departments = []
    @start_column = ""
    @end_column = ""
    @questions = []
    
    @indexer = Search.new()
    
    unless link_to_first_page
      warn "No #{section} data available for this date"
    else
      page = Page.new(link_to_first_page)
      parse_page(page)
      while page.next_url
        page = Page.new(page.next_url)
        parse_page(page)
      end
    
      #flush the buffer
      unless @snippet.empty? or @snippet.join("").length == 0
        store_debate(page)
        @snippet = []
      end
    end
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
                @snippet_type = "subject heading"
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
