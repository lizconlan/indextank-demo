require 'lib/parser'
require 'lib/search'
require 'models/page'
require 'models/member'

class WHDebatesParser < Parser
  attr_reader :section
  
  def initialize(date, house="Commons", section="Westminster Hall")
    super(date, house)
    @section = section
  end
  
  def get_section_index
    super(section)
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
    def parse_node(node, page)
      case node.name
        when "a"
          @last_link = node.attr("name") if node.attr("class") == "anchor"
          if node.attr("class") == "anchor-column"
            if @start_column == ""
              @start_column = node.attr("name").gsub("column_", "")
            else
              @end_column = node.attr("name").gsub("column_", "")
            end
          elsif node.attr("name") =~ /column_(.*)/  #older page format
            if @start_column == ""
              @start_column = node.attr("name").gsub("column_", "")
            else
              @end_column = node.attr("name").gsub("column_", "")
            end
          elsif node.attr("name") =~ /^\d*$/ #older page format
            @last_link = node.attr("name")
          end
        when "h3"
          unless @snippet.empty? or @snippet.join("").length == 0
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
          column_desc = ""
          member_name = ""
          if node.xpath("a") and node.xpath("a").length > 0
            @last_link = node.xpath("a").last.attr("name")
          end
          unless node.xpath("b").empty?
            node.xpath("b").each do |bold|
              if bold.text =~ /^\d+ [A-Z][a-z]+ \d{4} : Column (\d+(?:WH)?(?:WS)?(?:P)?(?:W)?)(?:-continued)?$/  #older page format
                if @start_column == ""
                  @start_column = $1
                else
                  @end_column = $1
                end
                column_desc = bold.text
              else 
                member_name = bold.text.strip
              end
            end
          else
            member_name = ""
          end
          
          text = node.text.gsub("\n", "").gsub(column_desc, "").squeeze(" ").strip
          #ignore column heading text
          unless text =~ /^\d+ [A-Z][a-z]+ \d{4} : Column (\d+(?:WH)?(?:WS)?(?:P)?(?:W)?)(?:-continued)?$/
            #check if this is a new contrib
            case member_name
              when /^(([^\(]*) \(in the Chair\):)/
                #the Chair
                name = $2
                post = "Debate Chair"
                member = Member.new(name, name, "", "", post)
                handle_contribution(@member, member, page)
                @contribution.segments << sanitize_text(text.gsub($1, "")).strip
              when /^(([^\(]*) \(([^\(]*)\):)/
                #we has a minister
                post = $2
                name = $3
                member = Member.new(name, "", "", "", post)
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
        @contribution = Contribution.new("#{page.url}\##{@last_link}", @start_column)
      else
        @contribution = Contribution.new("#{page.url}\##{@last_link}", @end_column)
      end
      if @members.keys.include?(new_member.search_name)
        new_member = @members[new_member.search_name]
      else
        @members[new_member.search_name] = new_member
      end
      @member = new_member
    end
    
    def store_debate(page)
      handle_contribution(@member, @member, page)
      
      if @segment_link #no point storing pointers that don't link back to the source
        segment_id = "#{doc_id}_wh_#{@count}"
        @count += 1
        names = []
        @members.each { |x, y| names << y.index_name unless names.include?(y.index_name) }
      
        column_text = ""
        if @start_column == @end_column or @end_column == ""
          column_text = @start_column
        else
          column_text = "#{@start_column} to #{@end_column}"
        end
      
        doc = {:title => sanitize_text("Debate: #{@subject}"),
         :volume => page.volume,
         :columns => column_text,
         :part => sanitize_text(page.part.to_s),
         :members => "| #{names.join(" | ")} |".squeeze(" "),
         :chair => @chair,
         :subject => @subject,
         :url => @segment_link,
         :house => house,
         :section => section,
         :timestamp => Time.parse(date).to_i
        }
            
        categories = {"house" => house, "section" => section}
      
        @indexer.add_document(segment_id, doc, @snippet.join(" "), categories, "idx")

        @start_column = @end_column
      
        p @subject
        p segment_id
        p @segment_link
        p ""
      
        store_member_contributions(page, @segment_link)
      end
    end
    
    def store_member_contributions(page, debate_link)
      p ""
      @members.keys.each do |member|
        p "storing contributions for: #{member}"
        @members[member].contributions.each do |contribution|
          segment_id = "#{doc_id}_wh_contribution_#{@contribution_count}"
          @contribution_count += 1
      
          column_text = ""
          if contribution.start_column == contribution.end_column or contribution.end_column == ""
            column_text = contribution.start_column
          else
            column_text = "#{contribution.start_column} to #{contribution.end_column}"
          end
          
          doc = {:title => sanitize_text("#{@subject}"),
             :timestamp => Time.parse(date).to_i,
             :member => @members[member].index_name,
             :constituency => @members[member].constituency,
             :post => @members[member].post,
             :volume => page.volume,
             :columns => column_text,
             :part => sanitize_text(page.part.to_s),
             :chair => @chair,
             :subject => @subject,
             :url => contribution.link,
             :house => house,
             :section => section,
             :debate_url => debate_link
            }
            
          categories = {
              "house" => house, 
              "section" => section, 
              "subject" => @subject, 
              "member" => @members[member].index_name,
              "parent" => "#{@subject}|#{debate_link}"
            }
            
          @indexer.add_document(segment_id, doc, contribution.segments.join(" "), categories, "contributions")

          p "#{@members[member].index_name}, #{@subject}"
          p segment_id
          p ""
        end
      end
      @members = {}
      @member = nil
    end

end