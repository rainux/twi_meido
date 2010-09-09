class User
  include MongoMapper::Document
  plugin MongoMapper::Plugins::IdentityMap

  key :jabber_id,               String, :index => true
  key :request_token,           String
  key :request_token_secret,    String
  key :oauth_token,             String
  key :oauth_token_secret,      String
  key :notification,            Array, :default => [:mention, :dm]
  key :tracking_keywords,       Array
  key :viewed_tweets,           Array, :typecast => 'Hashie::Mash'
  timestamps!

  key :screen_name,             String
  key :twitter_user_id,         Integer
  key :twitter_user_created_at, DateTime

  Notifications = [:home, :mention, :dm, :track]

  class << self
    def create_or_update_from_tweet(tweet)
      twitter_user =
        if tweet.user
          tweet.user
        elsif tweet.retweeted_status
          tweet.retweeted_status.user
        else
          nil
        end
      return unless twitter_user

      user = first_or_new(:twitter_user_id => twitter_user.id)
      user.update_attributes(twitter_user)
    end
  end

  def view_tweet!(tweet)
    tweet = tweet.retweeted_status if tweet.retweeted_status
    short_id = viewed_tweets.index {|t| t.id == tweet.id }
    if short_id
      short_id + 1
    else
      push :viewed_tweets => tweet
      viewed_tweets.count
    end
  end

  def viewed_tweet(short_id)
    viewed_tweets[short_id - 1]
  end

  def reset_short_id
    viewed_tweets.count.times do
      pop :viewed_tweets => -1
    end
  end

  def authorized?
    !oauth_token.blank? && !oauth_token_secret.blank?
  end

  def initialize(attrs = {})
    rename_twitter_user_attributes(attrs)
    super
  end

  def update_attributes(attrs = {})
    rename_twitter_user_attributes(attrs)
    super
  end

  private
  def rename_twitter_user_attributes(attrs)
    attrs[:twitter_user_id] = attrs.delete(:id) if attrs.key? :id
    attrs[:twitter_user_created_at] = attrs.delete(:created_at) if attrs.key? :created_at
  end
end
