require 'rubygems'
require 'bundler/setup'
Bundler.require
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

  setup AppConfig.meido.email, AppConfig.meido.password, AppConfig.meido.host

  when_ready do
    puts "TwiMeido #{AppConfig.meido.email} ready."

    client.roster.each do |jid, roster_item|
      discover :info, jid, nil
    end
  end

  subscription :request? do |s|
    User.first_or_create(:email => s.from.stripped.to_s)
    write_to_stream s.approve!
    say s.to, <<MESSAGE
おかえりなさいませ、ご主人様！

Use -oauth command to bind your Twitter account.
MESSAGE
  end

  message :chat?, :body do |m|
    user = User.first_or_create(:email => m.from.stripped.to_s)
    TwitterClient.auth = {
      :type => :oauth,
      :consumer_key => AppConfig.twitter.consumer_key,
      :consumer_secret => AppConfig.twitter.consumer_secret,
      :token => user.oauth_token,
      :token_secret => user.oauth_token_secret
    }
    say m.from, process_message(user, m)
  end

  def self.broadcast(tweet)
    client.roster.each do |jid, roster_item|
      user = User.first_or_create(:email => jid.to_s)
      if user.screen_name.blank? ||
        !tweet.text.downcase.include?(user.screen_name.downcase)
        next
      end

      begin
        if tweet.retweeted_status
          say jid, <<-TWEET
#{tweet.retweeted_status.user.screen_name}: #{CGI.unescapeHTML(tweet.retweeted_status.text)}
[ ID: #{tweet.id} ] [ #{tweet.retweeted_status.created_at} ]
[ Retweeted by @#{tweet.user.screen_name} ]
          TWEET
        else
          say jid, <<-TWEET
#{tweet.user.screen_name}: #{CGI.unescapeHTML(tweet.text)}
[ ID: #{tweet.id} ]
          TWEET
        end
      rescue
        p $!
      end
    end
  end
end

EM.run do
  TwiMeido.run

  TwitterStream = Twitter::JSONStream.connect(
    :filters => User.all.collect(&:screen_name),
    :auth => "#{AppConfig.twitter.username}:#{AppConfig.twitter.password}"
  )

  TwitterStream.each_item do |item|
    begin
      tweet = Hashie::Mash.new(JSON.parse(item))
      TwiMeido.broadcast(tweet)
    rescue
      p $!
    end
  end
end
