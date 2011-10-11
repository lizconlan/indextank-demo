class Member
  include MongoMapper::Document
  scope :by_name, lambda { |name| where(:name => name) }
  scope :by_post, lambda { |post| where(:post => post) }
  
  key :name, String
  key :post, String
  key :contribution_ids, Array
  
  many :contributions, :in => :contribution_ids
end

class Contribution
  include MongoMapper::Document
  
  belongs_to :member
  
  key :member_id, BSON::ObjectId
  key :url, String
  key :date, String
  key :section, String
  key :subject, String
end