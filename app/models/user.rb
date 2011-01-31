class User
  include MongoMapper::Document
  include TwiMeido::Command
  plugin MongoMapper::Plugins::IdentityMap

  key :jabber_id,               String, :index => true
  key :request_token,           String
  key :request_token_secret,    String
  key :oauth_token,             String, :index => true
  key :oauth_token_secret,      String, :index => true
  key :notification,            Array, :default => [:mention, :dm, :event]
  key :tracking_keywords,       Array
  key :viewed_tweet_ids,        Array
  key :last_short_id,           Integer, :default => -1
  key :last_mention_id,         Integer
  key :last_dm_id,              Integer
  timestamps!

  key :screen_name,             String
  key :twitter_user_id,         Integer, :index => true
  key :twitter_user_created_at, DateTime

  Notifications = [:home, :mention, :dm, :event, :track]
  MaxShortId = 'ZZ'.as_b26_to_i

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
    Tweet.create(tweet) unless tweet.kind_of?(Tweet) || viewed_tweet_ids.include?(tweet.id)
    view_tweet_id!(tweet.id)
  end

  def view_tweet_id!(tweet_id)
    short_id = viewed_tweet_ids.index(tweet_id)
    return short_id if short_id

    self.last_short_id = -1 if self.last_short_id >= MaxShortId
    self.last_short_id += 1
    viewed_tweet_ids[self.last_short_id] = tweet_id
    save
    self.last_short_id
  end

  def viewed_tweet(short_id)
    Tweet.find(viewed_tweet_ids[short_id])
  end

  def fetch_tweet(short_id_or_tweet_id)
    if short_id_or_tweet_id.respond_to?(:is_valid_b26?) && short_id_or_tweet_id.is_valid_b26?
      short_id_or_tweet_id = short_id_or_tweet_id.as_b26_to_i
    else
      short_id_or_tweet_id = short_id_or_tweet_id.to_i
    end
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

  def mentioned_by?(tweet)
    tweet.entities.user_mentions.collect(&:id).include?(twitter_user_id)
  end

  def tracking?(tweet)
    tweet_text = tweet.text.downcase
    found = tracking_keywords.select do|keyword|
      tweet_text.include?(keyword.downcase)
    end
    !found.empty?
  end

  def connect_user_streams
    stream = Twitter::JSONStream.connect(
      :host => 'userstream.twitter.com',
      :path => '/2/user.json',
      :ssl => true,
      :user_agent => "TwiMeido v#{TwiMeido::VERSION}",
      # :filters => tracking_keywords,
      :oauth => {
        :consumer_key => AppConfig.twitter.consumer_key,
        :consumer_secret => AppConfig.twitter.consumer_secret,
        :access_key      => oauth_token,
        :access_secret   => oauth_token_secret
      }
    )

    stream.each_item do |item|
      begin
        item = JSON.parse(item)
        if item.respond_to?(:each_pair)
          item = Hashie::Mash.new(item)
          TwiMeido.current_user = self
          TwiMeido.process_user_stream(item)
        end
      rescue => error
        puts error.inspect
        puts error.backtrace.join("\n")
      end
    end

    stream.on_error do |message|
      puts "User streams error:\n#{message}"
    end

    stream.on_no_data do
      reconnect_user_streams
    end

    stream.on_unauthorized do
      remove_oauth_token
      @rest_api_pulling_timer.cancel
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

  def remove_oauth_token
    self.oauth_token = nil
    self.oauth_token_secret = nil
    save
  end

  def setup_rest_api_pulling
    @rest_api_pulling_timer = EM.add_periodic_timer(60) do
      pull_rest_api
    end
  end

  def pull_rest_api
    TwitterClient.auth = {
      :type => :oauth,
      :consumer_key => AppConfig.twitter.consumer_key,
      :consumer_secret => AppConfig.twitter.consumer_secret,
      :token => oauth_token,
      :token_secret => oauth_token_secret
    }
    pull_mentions if notification.include?(:mention)
    pull_dms if notification.include?(:dm)
  end

  private
  def rename_twitter_user_attributes(attrs)
    attrs[:twitter_user_id] = attrs.delete(:id) if attrs.key? :id
    attrs[:twitter_user_created_at] = attrs.delete(:created_at) if attrs.key? :created_at
  end

  def pull_mentions
    return unless last_mention_id

    tweets = TwitterClient.statuses.mentions?(
      :since_id => last_mention_id, :include_entities => true
    )
    return if tweets.empty?

    new_last_mention_id = tweets.first.id

    tweets.collect! do |tweet|
      format_tweet(tweet)
    end

    message = tweets.reverse.join("\n")
    message += <<-TEXT

[ Provided by REST API ]
    TEXT

    TwiMeido.send_message(self, message)
    update_attributes(:last_mention_id => new_last_mention_id)
  end

  def pull_dms
    return unless last_dm_id

    dms = TwitterClient.direct_messages?(
      :since_id => last_dm_id, :include_entities => true
    )
    return if dms.empty?

    new_last_dm_id = dms.first.id

    dms.collect! do |dm|
      <<-DM
DM from #{dm.sender.screen_name} (#{dm.sender.name}):
#{CGI.unescapeHTML(dm.text)}
      DM
    end

    message = dms.reverse.join("\n")
    message += <<-TEXT

[ Provided by REST API ]
    TEXT

    TwiMeido.send_message(self, message)
    update_attributes(:last_dm_id => new_last_dm_id)
  end
end
