MongoMapper.database = 'twi_meido'

class User
  include MongoMapper::Document
  key :email,                   String, :index => true, :unique => true
  key :twitter_user_id,         Integer
  key :screen_name,             String
  key :request_token,           String
  key :request_token_secret,    String
  key :oauth_token,             String
  key :oauth_token_secret,      String
  key :notification,            Array, :default => [:mention, :dm]
  timestamps!

  Notifications = [:home, :mention, :dm]

  def authorized?
    !oauth_token.blank? && !oauth_token_secret.blank?
  end
end
