class Member
  include MongoMapper::Document
  
  many :contributions, :in => :contribution_ids
  many :debates, :in => :debate_ids
  
  key :name, String
  key :post, String
  key :contribution_ids, Array
  key :debate_ids, Array
end