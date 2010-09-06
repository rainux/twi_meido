DataMapper.setup(:default, 'sqlite:twi_meido.db')

class User
  include DataMapper::Resource
  property :id,                     Serial
  property :email,                  String,   :unique_index => true
  property :twitter_user_id,        Integer
  property :screen_name,            String
  property :request_token,          String
  property :request_token_secret,   String
  property :oauth_token,            String
  property :oauth_token_secret,     String
  property :created_at,             DateTime
  property :updated_at,             DateTime
  property :notification,           Flag[:home, :mention, :dm], :default => [:mention, :dm]

  def authorized?
    !oauth_token.blank? && !oauth_token_secret.blank?
  end
end

DataMapper.auto_upgrade!
