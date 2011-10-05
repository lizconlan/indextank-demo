class Member
  include MongoMapper::Document
  
  key :name, String
  key :post, String
  
  many :contributions
end

class Contribution
  include MongoMapper::EmbeddedDocument
  
  key :url, String
  key :date, String
  key :section, String
end