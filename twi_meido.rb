require 'rubygems'
require 'bundler/setup'
Bundler.require
require 'cgi'
require 'yaml'

require 'grackle_ext'
require 'command'
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
  :token => AppConfig.twitter.token,
  :token_secret => AppConfig.twitter.token_secret
}

module TwiMeido
  extend Blather::DSL

  def self.run
    client.run
  end

  setup AppConfig.meido.email, AppConfig.meido.password

  when_ready do
    puts "TwiMeido #{AppConfig.meido.email} ready."

    client.roster.each do |jid, roster_item|
      discover :info, jid, nil
    end
  end

  subscription :request? do |s|
    write_to_stream s.approve!
  end

  message :chat?, :body do |m|
    say m.from, process_message(m)
  end

  def self.broadcast(tweet)
    client.roster.each do |jid, roster_item|
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

  stream = Twitter::JSONStream.connect(
    :path => '/1/statuses/filter.json?track=rainux',
    :auth => "#{AppConfig.twitter.username}:#{AppConfig.twitter.password}"
  )

  stream.each_item do |item|
    begin
      tweet = Hashie::Mash.new(JSON.parse(item))
      TwiMeido.broadcast(tweet)
    rescue
      p $!
    end
  end
end
