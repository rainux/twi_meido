class Tweet
  include MongoMapper::Document

  key :_id, Integer, :index => true, :required => true
  key :entities, Hashie::Mash
  key :user, Hashie::Mash
  key :retweeted_status, Hashie::Mash

  class << self
    def fetch(id)
      Tweet.find(id) || Tweet.create(
        TwitterClient.statuses.show._(id).json?
      )
    rescue
    end
  end
end
