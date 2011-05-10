require 'rubygems'
require 'bundler/setup'
Bundler.require
require 'active_support/time_with_zone'
require 'yaml'
require 'twi_meido/version'

MongoMapper.database = 'twi_meido'

unless defined?(require_relative)
  alias require_relative require
end

require 'twi_meido/base26'
require 'twi_meido/grackle_ext'
require 'twi_meido/mash_ext'
require 'twi_meido/command'
require 'app/models/user'
require 'app/models/tweet'
require 'app/models/directmessage'
require 'twi_meido/commands/repeat'
require 'twi_meido/commands/account'
require 'twi_meido/commands/location'
require 'twi_meido/commands/timeline'
require 'twi_meido/commands/utility'
require 'twi_meido/commands/not_implemented'
require 'twi_meido/commands/tweet'

AppConfig = Hashie::Mash.new(YAML.load_file('config.yml'))

module TwiMeido
  extend Blather::DSL

  class << self
    attr_accessor :user_streams

    def current_user
      Thread.current[:current_user]
    end

    def current_user=(user)
      Thread.current[:current_user] = user
    end
  end

  def self.run
    client.run
  end

  setup AppConfig.meido.jabber_id, AppConfig.meido.password, AppConfig.meido.host

  when_ready do
    client.roster.each do |jid, roster_item|
      discover :info, jid, nil
    end

    connect_user_streams
    set_status :available, AppConfig.meido.status_message

    puts "TwiMeido #{AppConfig.meido.jabber_id} ready."
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
    operation = lambda {
      self.current_user = User.first_or_create(:jabber_id => m.from.stripped.to_s)
      process_message(current_user, m)
    }
    callback = lambda {|response|
      send_message(m.from, response)
    }
    EM.defer(operation, callback)
  end

  class << client
    def unregister_tmp_handler(id)
      @tmp_handlers.delete(id.to_s)
    end
  end

  status :state => :unavailable do |s|
    user = User.first_or_create(:jabber_id => s.from.stripped.to_s)
    stanza = Blather::Stanza::Presence.new
    stanza.id = stanza.object_id
    stanza.type = :probe
    stanza.to = s.from.strip! # Fail w/ resource?
    timer = EM::Timer.new(2) do
      client.unregister_tmp_handler stanza.id
      if user.notification.include? :home
        user.home_was_on = 1
        user.notification -= [:home]
      else
        user.home_was_on = 0
      end
      user.save
    end
    callback = lambda {
      timer.cancel
    }
    client.register_tmp_handler stanza.id, &callback
    client.write stanza
    true # Ensure the general handler is not called.
  end

  status do |s|
    user = User.first_or_create(:jabber_id => s.from.stripped.to_s)
    if user.home_was_on == 1
      user.home_was_on = -1
      user.notification += [:home]
      user.save
    end
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
    message = message.rstrip + "\n\n "
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

module EM
  class << self
    attr_reader :threadqueue
  end
end
