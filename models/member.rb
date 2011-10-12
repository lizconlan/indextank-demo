class Member
  include MongoMapper::Document
  
  many :contributions, :in => :contribution_ids
  
  key :name, String
  key :post, String
  key :contribution_ids, Set
end