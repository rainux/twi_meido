MongoMapper.database = 'twi_meido'

class User
  include MongoMapper::Document
  key :jabber_id,               String, :index => true, :unique => true
  key :request_token,           String
  key :request_token_secret,    String
  key :oauth_token,             String
  key :oauth_token_secret,      String
  key :notification,            Array, :default => [:mention, :dm]
  timestamps!

  key :screen_name,             String
  key :twitter_user_id,         Integer
  key :twitter_user_created_at, DateTime

  Notifications = [:home, :mention, :dm]

  def authorized?
    !oauth_token.blank? && !oauth_token_secret.blank?
  end
end
