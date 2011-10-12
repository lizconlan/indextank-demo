class Debate
  include MongoMapper::Document
  
  many :contributions, :in => :contribution_ids
  many :members, :in => :member_ids
  
  key :url, String
  key :date, String
  key :section, String
  key :subject, String
  key :contribution_ids, Array
  key :member_ids, Array
end