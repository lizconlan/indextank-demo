class Contribution
  include MongoMapper::Document
  
  belongs_to :member
  belongs_to :debate
  
  key :member_id, BSON::ObjectId
  key :url, String
end