require 'rubygems'
require 'bundler/setup'
Bundler.require
require 'active_support/time_with_zone'
require 'cgi'
require 'yaml'

require 'grackle_ext'
require 'models'
require 'command'
require 'commands/account'
require 'commands/timeline'
require 'commands/not_implemented'
require 'commands/tweet'

AppConfig = Hashie::Mash.new(YAML.load_file('config.yml'))

TwitterClient = Grackle::Client.new(
  :handlers => {:json => Grackle::Handlers::JSON2MashHandler.new }
)

TwitterClient.auth = {
  :type => :oauth,
  :consumer_key => AppConfig.twitter.consumer_key,
  :consumer_secret => AppConfig.twitter.consumer_secret,
}

module TwiMeido
  extend Blather::DSL

  def self.run
    client.run
  end

  setup AppConfig.meido.jabber_id, AppConfig.meido.password, AppConfig.meido.host

  when_ready do
    puts "TwiMeido #{AppConfig.meido.jabber_id} ready."

    client.roster.each do |jid, roster_item|
      discover :info, jid, nil
    end
  end

  subscription :request? do |s|
    User.first_or_create(:jabber_id => s.from.stripped.to_s)
    write_to_stream s.approve!
    say s.to, <<MESSAGE
おかえりなさいませ、ご主人様！

Use -oauth command to bind your Twitter account.
MESSAGE
  end

  message :chat?, :body do |m|
    user = User.first_or_create(:jabber_id => m.from.stripped.to_s)
    TwitterClient.auth = {
      :type => :oauth,
      :consumer_key => AppConfig.twitter.consumer_key,
      :consumer_secret => AppConfig.twitter.consumer_secret,
      :token => user.oauth_token,
      :token_secret => user.oauth_token_secret
    }
    say m.from, process_message(user, m)
  end

  def self.process_user_stream(user, tweet)
    if tweet.entities
      if user.notification.include?(:home)
        say user.jabber_id, format_tweet(tweet)

      elsif user.notification.include?(:mention) &&
        tweet.entities.user_mentions.collect(&:screen_name).include?(user.screen_name)

        say user.jabber_id, format_tweet(tweet)

      elsif user.notification.include?(:track)
        tweet_text = tweet.text.downcase
        keywords = user.tracking_keywords.select do|keyword|
          tweet_text.include?(keyword.downcase)
        end

        unless keywords.empty?
          say user.jabber_id, format_tweet(tweet)
        end
      end

    elsif tweet.direct_message && user.notification.include?(:dm) &&
      tweet.direct_message.sender.screen_name != user.screen_name
      say user.jabber_id, format_tweet(tweet)
    end
  end
end

EM.run do
  TwiMeido.run

  user_streams = User.all.collect do |user|
    next unless user.authorized?

    stream = Twitter::JSONStream.connect(
      :host => 'betastream.twitter.com',
      :path => '/2b/user.json',
      :ssl => true,
      :filters => user.tracking_keywords,
      :oauth => {
        :consumer_key => AppConfig.twitter.consumer_key,
        :consumer_secret => AppConfig.twitter.consumer_secret,
        :access_key      => user.oauth_token,
        :access_secret   => user.oauth_token_secret
      }
    )

    stream.each_item do |item|
      begin
        tweet = Hashie::Mash.new(JSON.parse(item))
        User.create_or_update_from_tweet(tweet)
        TwiMeido.process_user_stream(user.reload, tweet)
      rescue
        puts "#{$!.inspect} #{__LINE__}"
      end
    end

    [user.id, stream]
  end

  UserStreams = Hash[user_streams]
end
