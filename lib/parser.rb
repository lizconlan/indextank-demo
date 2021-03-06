require 'nokogiri'
require 'rest-client'
require 'date'
require 'time'

require 'mongo_mapper'
require 'models/member'
require 'models/contribution'
require 'models/debate'

require 'lib/indexer'
require 'models/hansard_page'
require 'models/hansard_member'

class Parser
  attr_reader :date, :doc_id, :house
  
  COLUMN_HEADER = /^\d+ [A-Z][a-z]+ \d{4} : Column (\d+(?:WH)?(?:WS)?(?:P)?(?:W)?)(?:-continued)?$/
  
  def initialize(date, house="Commons")
    @date = date
    @house = house
    @doc_id = "#{date}_hansard_#{house[0..0].downcase()}"
    
    #in the wrong place - should be in the Rakefile (when there is one)
    db_config = YAML::load(File.read("config/mongo.yml"))
    MongoMapper.connection = Mongo::Connection.new(db_config['host'], db_config['port'])
    MongoMapper.database = db_config['database']
    MongoMapper.database.authenticate(db_config['username'], db_config['password'])
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
      content_section = doc.xpath("//div[@id='content-small']/table/tr/td[1]/p[3]/a[1]")
    end
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
    elsif content.children.size < 10
      content = page.doc.xpath("//div[@id='content-small']/table/tr/td[1]")
    end
    content.children.each do |child|
      if child.class == Nokogiri::XML::Element
        parse_node(child, page)
      end
    end
  end
  
  private
    def handle_contribution(member, new_member, page)
      if @contribution and member
        unless @members.keys.include?(member.search_name)
          if @section_members.keys.include?(member.search_name)
            @members[member.search_name] = @section_members[member.search_name]
          else
            @members[member.search_name] = member
            @section_members[member.search_name] = member
          end
        end
        @contribution.end_column = @end_column
        @members[member.search_name].contributions << @contribution
      end
      if @end_column == ""
        @contribution = HansardContribution.new("#{page.url}\##{@last_link}", @start_column)
      else
        @contribution = HansardContribution.new("#{page.url}\##{@last_link}", @end_column)
      end
      if new_member
        if @members.keys.include?(new_member.search_name)
          new_member = @members[new_member.search_name]
        elsif @section_members.keys.include?(new_member.search_name)
          new_member = @section_members[new_member.search_name]
        else
          @members[new_member.search_name] = new_member
          @section_members[new_member.search_name] = new_member
        end
        @member = new_member
      end
    end
    
    def store_member_contributions
      debate = Debate.find_or_create_by_url(@segment_link)
      debate.section = @section
      debate.subject = @subject
      debate.date = @date
      
      @members.keys.each do |member|
        p "storing: #{@members[member].index_name}"
        mp = Member.find_or_create_by_name(@members[member].index_name)
        
        unless mp.debate_ids.include?(debate.id)
          mp.debate_ids << debate.id
        end
        
        unless debate.member_ids.include?(mp.id)
          debate.member_ids << mp.id
        end
        
        @members[member].contributions.each do |contrib|
          contribution = Contribution.find_or_create_by_url(contrib.link)
          contribution.member = mp
          # contribution.section = @section
          # contribution.subject = @subject
          # contribution.date = @date
          contribution.save
          
          unless mp.contribution_ids.include?(contribution.id)
            mp.contribution_ids << contribution.id
          end
          
          unless debate.contribution_ids.include?(contribution.id)
            debate.contribution_ids << contribution.id
          end
        end
        mp.save
      end
      debate.save
      @members = {}
      @member = nil
      p ""
      p ""
    end
    
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
