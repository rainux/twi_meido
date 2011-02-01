require 'rubygems'
require 'bundler/setup'
Bundler.require
require 'active_support/time_with_zone'
require 'cgi'
require 'yaml'

MongoMapper.database = 'twi_meido'

unless defined?(require_relative)
  alias require_relative require
end

require_relative 'base26'
require_relative 'grackle_ext'
require_relative 'mash_ext'
require_relative 'command'
require_relative 'app/models/user'
require_relative 'app/models/tweet'
require_relative 'commands/account'
require_relative 'commands/timeline'
require_relative 'commands/utility'
require_relative 'commands/not_implemented'
require_relative 'commands/tweet'

AppConfig = Hashie::Mash.new(YAML.load_file('config.yml'))

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
    response = process_message(@current_user, m)
    send_message(m.from, response)
  end

  def self.process_user_stream(item)
    notification = extract_notification(item)
    send_message(current_user, notification) if notification
  end

  def self.process_rest_polling(items)
    items = items.map do |item|
      extract_notification(item)
    end.compact.reverse

    unless items.empty?
      items << '[ Provided by REST API polling ]'
      notification = items.join("\n")
      send_message(current_user, notification)
    end
  end

  def self.send_message(user, message)
    # The trailing space can prevent Google Talk chomp the blank line
    message = message.rstrip + "\n "
    jabber_id = user.respond_to?(:jabber_id) ? user.jabber_id : user
    say jabber_id, message
  end

  def self.connect_user_streams
    @user_streams = {}
    User.authorized.each do |user|
      user.connect_user_streams
      user.setup_rest_polling
    end
    puts "#{user_streams.count} user streams connected."
  end
end

EM.run do
  TwiMeido.run
end
