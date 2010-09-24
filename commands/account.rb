module TwiMeido
  module AccountCommands
    extend Command

    define_command :oauth, /^-oauth$/ do |user, message|
      client = TwitterOAuth::Client.new(
        :consumer_key => AppConfig.twitter.consumer_key,
        :consumer_secret => AppConfig.twitter.consumer_secret
      )
      request_token = client.request_token(
        :oauth_callback => 'oob'
      )
      user.update_attributes(
        :request_token => request_token.token,
        :request_token_secret => request_token.secret
      )

      <<-MESSAGE
Please visit the following URL to confirm your OAuth request:
#{request_token.authorize_url}
After that you'll get a PIN code, use it with -bind command to complete the OAuth process like this:
-bind PIN_CODE
      MESSAGE
    end

    define_command :bind, /^-bind\s*(.+)$/ do |user, message, params|
      begin
        client = TwitterOAuth::Client.new(
          :consumer_key => AppConfig.twitter.consumer_key,
          :consumer_secret => AppConfig.twitter.consumer_secret
        )
        access_token = client.authorize(
          user.request_token,
          user.request_token_secret,
          :oauth_verifier => params[1]
        )
        account = Hashie::Mash.new(client.info)
        user.update_attributes(
          :twitter_user_id => account.id,
          :screen_name => account.screen_name,
          :oauth_token => access_token.token,
          :oauth_token_secret => access_token.secret
        )
        user.reconnect_user_streams

      rescue OAuth::Unauthorized
        return 'OAuth with Twitter failed, please retry by use -oauth command.'
      end

      <<-MESSAGE
Successfully bound your Twitter account, now you can:
* Use commands to access your Twitter account.
* Receive tweets which contain your username nearly real-time.
* Tweet to Twitter by directly send your tweets.
      MESSAGE
    end

    define_command :on, /^-on\s*(.*)$/ do |user, message, params|
      target = params[1].to_sym rescue nil

      if User::Notifications.include?(target)

        if user.notification.include?(target)
          "Real-time notification for #{target} already turned on, ご主人様."
        else
          user.notification += [target]
          user.save
          "Real-time notification for #{target} turned on, ご主人様."
        end

      else
        <<-MESSAGE
ご主人様, please use one of the following real-time notification types as parameter:
#{User::Notifications.collect(&:to_s).join(' ')}
Currently you've turned on #{user.notification.join(' ')}.
        MESSAGE
      end
    end

    define_command :off, /^-off\s*(.*)$/ do |user, message, params|
      target = params[1].to_sym rescue nil

      if User::Notifications.include?(target)

        if user.notification.include?(target)
          user.notification -= [target]
          user.save
          "Real-time notification for #{target} turned off, ご主人様."
        else
          "Real-time notification for #{target} already turned off, ご主人様."
        end

      else
        <<-MESSAGE
ご主人様, please use one of the following real-time notification types as parameter:
#{User::Notifications.collect(&:to_s).join(' ')}
Currently you've turned on #{user.notification.join(' ')}.
        MESSAGE
      end
    end

    define_command :track, /^-track\s*(.*)$/ do |user, message, params|
      keywords = params[1].split(/\s+/)
      user.tracking_keywords += keywords
      user.tracking_keywords.uniq!
      user.save
      user.reconnect_user_streams

      <<-MESSAGE
ご主人様, I'll tracking tweets contain "#{user.tracking_keywords.join(' ')}" for you.
Please make sure you've turned track on via command -on track.
      MESSAGE
    end

    define_command :untrack, /^-untrack\s*(.*)$/ do |user, message, params|
      keywords = params[1].split(/\s+/)
      user.tracking_keywords -= keywords
      user.tracking_keywords.uniq!
      user.save
      user.reconnect_user_streams

      <<-MESSAGE
ご主人様, I'll tracking tweets contain "#{user.tracking_keywords.join(' ')}" for you.
Please make sure you've turned track on via command -on track.
      MESSAGE
    end

    define_command :reset_short_id, /^-reset$/ do |user, message|
      user.reset_short_id
      'Short ID reset, ご主人様.'
    end
  end
end
