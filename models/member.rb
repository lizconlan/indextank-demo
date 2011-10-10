class Member
  include MongoMapper::Document
  
  key :name, String
  key :post, String
  
  many :contributions
  
  
  def self.find_or_create(name)
    member = nil
    name = name.strip
    if name.downcase() =~ /^the / or name.downcase() =~ / speaker$/
      member = Member.first(:post => name)
      unless member
        member = Member.new({:post => name})
        member.save
      end
    else
      if name.split(" ").length > 1
        member = Member.first(:name => name)
        unless member
          member = Member.new({:name => name})
          member.save
        end
      end
    end
    member
  end
end

class Contribution
  include MongoMapper::EmbeddedDocument
  
  key :url, String
  key :date, String
  key :section, String
end