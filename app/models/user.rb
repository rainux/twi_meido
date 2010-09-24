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

  scope :authorized, where(:oauth_token.ne => nil, :oauth_token_secret.ne => nil)

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
      user.update_attributes(twitter_user) if user.new? || user.updated_at < 1.day.ago
    end
  end

  def view_tweet!(tweet)
    tweet = tweet.retweeted_status if tweet.retweeted_status
    short_id = viewed_tweets.index {|t| t.id == tweet.id }
    if short_id
      short_id + 1
    else
      viewed_tweets << tweet
      save
      viewed_tweets.count
    end
  end

  def viewed_tweet(short_id)
    viewed_tweets[short_id - 1]
  end

  def reset_short_id
    self.viewed_tweets = []
    save
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

  def connect_user_streams
    stream = Twitter::JSONStream.connect(
      :host => 'betastream.twitter.com',
      :path => '/2b/user.json',
      :ssl => true,
      :user_agent => "TwiMeido v#{TwiMeido::VERSION}",
      :filters => tracking_keywords,
        :oauth => {
        :consumer_key => AppConfig.twitter.consumer_key,
        :consumer_secret => AppConfig.twitter.consumer_secret,
        :access_key      => oauth_token,
        :access_secret   => oauth_token_secret
      }
    )

    stream.each_item do |item|
      begin
        tweet = Hashie::Mash.new(JSON.parse(item))
        TwiMeido.current_user = self
        TwiMeido.process_user_stream(tweet)
      rescue
        puts "#{$!.inspect} #{__LINE__}"
      end
    end

    puts "User streams for #{screen_name} connected"
    TwiMeido.user_streams[id] = stream
  end

  def reconnect_user_streams
    TwiMeido.user_streams[id].stop if TwiMeido.user_streams[id]
    connect_user_streams
  end

  private
  def rename_twitter_user_attributes(attrs)
    attrs[:twitter_user_id] = attrs.delete(:id) if attrs.key? :id
    attrs[:twitter_user_created_at] = attrs.delete(:created_at) if attrs.key? :created_at
  end
end
