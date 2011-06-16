class Member
  attr_reader :name, :post, :party, :constituency, :search_name
  attr_accessor :contributions
  
  def initialize(name, constituency="", party="", post="")
    @search_name = format_search_name(name)
    @name = name
    @constituency = constituency
    @party = party
    @post = post
    @contributions = []
  end
  
  private
    def format_search_name(member_name)
      if member_name =~ /^Mr |^Ms |^Mrs |^Miss /
        parts = member_name.split(" ").reverse
        name = parts.pop
        parts.pop #drop the firstname
        member_name = "#{name} #{parts.reverse.join(" ")}"
      end
      member_name
    end
end

class Contribution
  attr_reader :link, :start_column
  attr_accessor :end_column, :segments
  
  def initialize(link, start_column)
    @link = link
    @start_column = start_column
    @end_column = ""
    @segments = []
  end
end