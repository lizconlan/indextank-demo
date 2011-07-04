require 'yaml'
require 'rest-client'
require 'json'

class Catalogue
  def initialize
    if ENV['RACK_ENV'] && ENV['RACK_ENV'] == 'production' #heroku
      @api_key = ENV['mongo_key']
      @api_secret = ENV['mongo_secret']
    else
      mongo_conf = YAML.load(File.read('config/mongohq.yml')) 
      @api_key = mongo_conf[:apikey]
      @api_secret = mongo_conf[:apisecret]
    end
  end
  
  def all
    #ToDo: add error handling
    response = RestClient.get("https://#{@api_key}:#{@api_secret}@mongohq.com/api/databases/hansard-search/collections/indexed/documents")
    JSON.parse(response.body)
  end
  
  def find(q)
    #ToDo: add error handling
    response = RestClient.get("https://#{@api_key}:#{@api_secret}@mongohq.com/api/databases/hansard-search/collections/indexed/documents", :params => {"q" => q})
    JSON.parse(response.body)
  end
  
  def add(doc)
    #ToDo: add error handling
    #...and check doc is sensible?
    doc = JSON.generate(doc)
    response = RestClient.post("https://#{@api_key}:#{@api_secret}@mongohq.com/api/databases/hansard-search/collections/indexed/documents", "document" => doc)
    JSON.parse(response.body)
  end
end