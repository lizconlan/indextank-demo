require 'lib/parser'
require 'lib/page'
require 'lib/test'
require 'lib/member'

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
    
    content_section = doc.xpath("//div[@id='content-small']/p[3]/a")
    if content_section.empty?
      content_section = doc.xpath("//div[@id='maincontent1']/div/a[1]")
    end
    relative_path = content_section.attr("href").value.to_s
    "http://www.publications.parliament.uk#{relative_path[0..relative_path.rindex("#")-1]}"
  end
  
  def parse_pages
    @page = 0
    @count = 0
    @contribution_count = 0

    @members = {}
    @member = nil
    @contribution = nil
    
    @last_link = ""
    @snippet = []
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
      store_debate(page)
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
          end
        when "h3"
          unless @snippet.empty?
            store_debate(page)
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
          unless node.xpath("a").empty?
            @last_link = node.xpath("a").last.attr("name")
          end
          unless node.xpath("b").empty?
            member_name = node.xpath("b").text.strip
          else
            member_name = ""
          end
          
          text = node.text.gsub("\n", "").squeeze(" ").strip
          #ignore column heading text
          unless text =~ /^\d+ [A-Z][a-z]+ \d{4} : Column \d+(WH)?$/            
            #check if this is a new contrib
            case member_name
              when /^(([^\(]*) \(([^\(]*)\):)/
                #we has a minister
                post = $2
                name = $3
                member = Member.new(name, "", "", "", post)
                handle_contribution(@member, member, page)
                @contribution.segments << sanitize_text(text.gsub($1, "")).strip
              when /^(([^\(]*) \(in the Chair\):)/
                #the Chair
                name = $2
                post = "Debate Chair"
                member = Member.new(name, name, "", "", post)
                handle_contribution(@member, member, page)
                @contribution.segments << sanitize_text(text.gsub($1, "")).strip
              when /^(([^\(]*) \(([^\(]*)\) \(([^\(]*)\):)/
                #an MP speaking for the first time in the debate
                name = $2
                constituency = $3
                party = $4
                member = Member.new(name, "", constituency, party)
                handle_contribution(@member, member, page)
                @contribution.segments << sanitize_text(text.gsub($1, "")).strip
              when /^(([^\(]*):)/
                #an MP who's spoken before
                name = $2
                member = Member.new(name, name)
                handle_contribution(@member, member, page)
                @contribution.segments << sanitize_text(text.gsub($1, "")).strip
              else
                if @member
                  unless text =~ /^Sitting suspended|^Sitting adjourned|^On resuming|^Question put/ or
                      text == "#{@member.search_name} rose\342\200\224"
                    @contribution.segments << sanitize_text(text)
                  end
                end
            end
            @snippet << sanitize_text(text)
          end
      end
    end

    def handle_contribution(member, new_member, page)
      if @contribution and member
        unless @members.keys.include?(member.search_name)
          @members[member.search_name] = member
        end
        @contribution.end_column = @end_column
        @members[member.search_name].contributions << @contribution
      end
      if @end_column == ""
        @contribution = Contribution.new(@segment_link = "#{page.url}\##{@last_link}", @start_column)
      else
        @contribution = Contribution.new(@segment_link = "#{page.url}\##{@last_link}", @end_column)
      end
      if @members.keys.include?(new_member.search_name)
        new_member = @members[new_member.search_name]
      else
        @members[new_member.search_name] = new_member
      end
      @member = new_member
    end
    
    def store_debate(page)
      s = Search.new()
      segment_id = "#{doc_id}_wh_#{@count}"
      @count += 1
      names = []
      @members.each { |x, y| names << y.index_name }
      s.index.document(segment_id).add(
        {:title => sanitize_text("Debate: #{@subject}"),
         :text => @snippet.join(" "),
         :volume => page.volume,
         :columns => "#{@start_column} to #{@end_column}",
         :part => sanitize_text(page.part.to_s),
         :members => "| #{names.join(" | ")} |".squeeze(" "),
         :chair => @chair,
         :subject => @subject,
         :url => @segment_link,
         :house => house,
         :section => section,
         :timestamp => Time.parse(date).to_i
        }
      )

      categories = {"house" => house, "section" => section}
      s.index.document(segment_id).update_categories(categories)

      p @subject
      p segment_id
      p ""
      
      store_member_contributions(page)
    end
    
    def store_member_contributions(page)      
      p ""
      @members.keys.each do |member|
        p "storing contributions for: #{member}"
        @members[member].contributions.each do |contribution|
          s = Search.new()
          segment_id = "#{doc_id}_wh_contribution_#{@contribution_count}"
          @contribution_count += 1
      
          column_text = ""
          if contribution.start_column == contribution.end_column
            column_text = contribution.start_column
          else
            column_text = "#{contribution.start_column} to #{contribution.end_column}"
          end
      
          s.contribs_index.document(segment_id).add(
            {:title => sanitize_text("#{@subject}"),
             :member => @members[member].index_name,
             :constituency => @members[member].constituency,
             :post => @members[member].post,
             :text => contribution.segments.join(" "),
             :volume => page.volume,
             :columns => column_text,
             :part => sanitize_text(page.part.to_s),
             :chair => @chair,
             :subject => @subject,
             :url => contribution.link,
             :house => house,
             :section => section,
             :timestamp => Time.parse(date).to_i
            }
          )

          categories = {"house" => house, "section" => section, "subject" => @subject, "member" => @members[member].index_name}
          s.contribs_index.document(segment_id).update_categories(categories)

          p "#{@members[member].index_name}, #{@subject}"
          p segment_id
          p ""
        end
      end
      @members = {}
      @member = nil
    end
end