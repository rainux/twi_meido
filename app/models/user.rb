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
  key :viewed_tweet_ids,        Array
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
    short_id = viewed_tweet_ids.index(tweet.id)
    if short_id
      short_id + 1
    else
      viewed_tweet_ids.clear if viewed_tweet_ids.count >= 1000
      viewed_tweet_ids << tweet.id
      Tweet.create(tweet)
      save
      viewed_tweet_ids.count
    end
  end

  def viewed_tweet(short_id)
    Tweet.find(viewed_tweet_ids[short_id - 1])
  end

  def reset_short_id
    self.viewed_tweet_ids = []
    save
  end

  def fetch_tweet(short_id_or_tweet_id)
    if short_id_or_tweet_id < 1000
      viewed_tweet(short_id_or_tweet_id)
    else
      Tweet.fetch(short_id_or_tweet_id)
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

  def connect_user_streams
    stream = Twitter::JSONStream.connect(
      :host => 'userstream.twitter.com',
      :path => '/2/user.json',
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
      rescue => error
        puts error.inspect
        puts error.backtrace.join("\n")
      end
    end

    stream.on_error do |message|
      puts "User streams error:\n#{message}"
    end

    stream.on_max_reconnects do |timeout, retries|
      puts "Max reconnects: timeout #{timeout}, #{retries} retries."
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
