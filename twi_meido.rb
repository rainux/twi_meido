require 'rubygems'
require 'bundler/setup'
Bundler.require
require 'active_support/time_with_zone'
require 'cgi'
require 'yaml'

require 'base26'
require 'grackle_ext'
require 'mash_ext'
MongoMapper.database = 'twi_meido'
require 'command'
require 'app/models/user'
require 'app/models/tweet'
require 'commands/account'
require 'commands/timeline'
require 'commands/utility'
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

  VERSION = '0.1.0'

  class << self
    attr_accessor :current_user
    attr_accessor :user_streams
  end

  def self.run
    client.run
  end

  setup AppConfig.meido.jabber_id, AppConfig.meido.password, AppConfig.meido.host

  when_ready do
    puts "TwiMeido #{AppConfig.meido.jabber_id} ready."

    client.roster.each do |jid, roster_item|
      discover :info, jid, nil
    end

    connect_user_streams
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
    @current_user = User.first_or_create(:jabber_id => m.from.stripped.to_s)
    TwitterClient.auth = {
      :type => :oauth,
      :consumer_key => AppConfig.twitter.consumer_key,
      :consumer_secret => AppConfig.twitter.consumer_secret,
      :token => @current_user.oauth_token,
      :token_secret => @current_user.oauth_token_secret
    }
    response = process_message(@current_user, m)
    # The trailing space can prevent Google Talk chomp the blank line
    response = response.rstrip + "\n "
    say m.from, response
  end

  def self.process_user_stream(tweet)
    notification = nil

    if tweet.entities
      if current_user.notification.include?(:home)
        User.create_or_update_from_tweet(tweet)
        notification = format_tweet(tweet)

      elsif current_user.notification.include?(:mention) &&
        tweet.entities.user_mentions.collect(&:screen_name).include?(current_user.screen_name)

        current_user.update_attributes(:last_mention_id => tweet.id)
        User.create_or_update_from_tweet(tweet)
        notification = format_tweet(tweet)

      elsif current_user.notification.include?(:track)
        tweet_text = tweet.text.downcase
        keywords = current_user.tracking_keywords.select do|keyword|
          tweet_text.include?(keyword.downcase)
        end

        unless keywords.empty?
          notification = format_tweet(tweet)
        end
      end

    elsif (tweet.event || tweet[:delete]) && current_user.notification.include?(:event)
      notification = format_event(tweet)

    elsif tweet.direct_message && current_user.notification.include?(:dm) &&
      tweet.direct_message.sender.screen_name != current_user.screen_name

      current_user.update_attributes(:last_dm_id => tweet.direct_message.id)
      notification = format_tweet(tweet)
    end

    if notification
      # The trailing space can prevent Google Talk chomp the blank line
      notification = notification.rstrip + "\n "
      say current_user.jabber_id, notification
    end
  end

  def self.send_message(user, message)
    # The trailing space can prevent Google Talk chomp the blank line
    message = message.rstrip + "\n "
    say user.jabber_id, message
  end

  def self.connect_user_streams
    @user_streams = {}
    User.authorized.each do |user|
      user.connect_user_streams
      user.setup_rest_api_pulling
    end
    puts "#{user_streams.count} user streams connected."
  end
end

EM.run do
  TwiMeido.run
end
