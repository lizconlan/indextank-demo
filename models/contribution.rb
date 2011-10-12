class Contribution
  include MongoMapper::Document
  
  belongs_to :member
  
  key :member_id, BSON::ObjectId
  key :url, String
  key :date, String
  key :section, String
  key :subject, String
end