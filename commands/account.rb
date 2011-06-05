module TwiMeido
  module AccountCommands
    extend Command

    define_command :oauth, /\Aoauth\Z/i do |user, message|
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
#{Googl.shorten(request_token.authorize_url).short_url}
After that you'll get a PIN code, use it with -bind command to complete the OAuth process like this:
-bind PIN_CODE
      MESSAGE
    end

    define_command :bind, /\Abind\s+(.+)\Z/i do |user, message, params|
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

        response = <<-MESSAGE
Successfully bound your Twitter account, now you can:
* Use commands to access your Twitter account.
* Receive tweets which contain your username nearly real-time.
* Tweet to Twitter by directly send your tweets.
        MESSAGE

      rescue OAuth::Unauthorized
        response = 'OAuth with Twitter failed, please retry by use -oauth command.'
      end

      response
    end

    define_command :on, /\Aon(?:\s+(.*))?\Z/i do |user, message, params|
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

    define_command :off, /\Aoff(?:\s+(.*))?\Z/i do |user, message, params|
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

    define_command :track, /\Atrack(?:\s+(.*))?\Z/i do |user, message, params|
      keywords = params[1].to_s.split(/\s+/)
      keywords.each do |keyword|
        keyword.downcase!
        if keyword[0] == 45 # '-'
          user.tracking_keywords -= [keyword[1..-1]]
        else
          user.tracking_keywords += [keyword]
        end
      end
      user.tracking_keywords.uniq!
      user.save

      "Now tracking in home: \"#{user.tracking_keywords.join(' ')}\", ご主人様."
    end

    define_command :world, /\Aworld(?:\s+(.*))?\Z/i do |user, message, params|
      keywords = params[1].to_s.split(/\s+/)
      keywords.each do |keyword|
        keyword.downcase!
        if keyword[0] == 45 # '-'
          user.tracking_keywords_world -= [keyword[1..-1]]
        else
          user.tracking_keywords_world += [keyword]
        end
      end
      user.tracking_keywords_world.uniq!
      user.save
      user.reconnect_user_streams unless keywords == []

      "Now tracking globally: \"#{user.tracking_keywords_world.join(' ')}\", ご主人様."
    end

    # NOTE: Not implemented by Twitter.
    #
    #define_command :user, /\Auser(?:\s+(.*))?\Z/i do |user, message, params|
    #  keywords = params[1].to_s.split(/\s+/)
    #  keywords.each do |keyword|
    #    begin
    #      result = TwiMeido.current_user.rest_api_client.users.show? :screen_name => keyword.sub(/^-?@?/, '')
    #      if keyword[0] == 45 # wtf?
    #        user.tracking_keywords_user -= [result.id]
    #      else
    #        user.tracking_keywords_user += [result.id]
    #      end
    #    rescue Grackle::TwitterError
    #      nil
    #    end
    #  end
    #  user.tracking_keywords_user.uniq!
    #  user.save
    #  user.reconnect_user_streams unless keywords == []
    #
    #  "Now tracking users: \"#{user.tracking_keywords_user.join(' ')}\", ご主人様."
    #end

    define_command :reconnect, /\Areconnect\Z/i do |user, message|
      user.reconnect_user_streams
      'User Streams reconnected, ご主人様.'
    end

    define_command :follow, /\Afo\s+(\S+)\Z/i do |user, message, params|
      screen_name = params[1]

      begin
        target_user = TwiMeido.current_user.rest_api_client.friendships.create!(:screen_name => screen_name)
        if !target_user.following && target_user.protected
          message = "Since @#{screen_name} is protected, a follow request has been sent, ご主人様."
        else
          message = "You're now following @#{screen_name}, ご主人様."
        end
      rescue Grackle::TwitterError => error
        if error.status == 403
          message = "You've already followed @#{screen_name}, ご主人様."
        else
          raise error
        end
      end

      message
    end

    define_command :unfollow, /\Aunfo\s+(\S+)\Z/i do |user, message, params|
      screen_name = params[1]

      TwiMeido.current_user.rest_api_client.friendships.destroy!(:screen_name => screen_name)

      "You're no longer following @#{screen_name} now, ご主人様."
    end

    define_command :if_follow, /\Aif\s+(\S+)(?:\s+(\S+))?\Z/i do |user, message, params|
      source_screen_name = params[2] ? params[1] : user.screen_name
      target_screen_name = params[2] ? params[2] : params[1]

      result = TwiMeido.current_user.rest_api_client.friendships.show?(
        :source_screen_name => source_screen_name, :target_screen_name => target_screen_name
      )

      source = source_screen_name == user.screen_name ? "You're" : "@#{source_screen_name} is"
      target = target_screen_name == user.screen_name ? 'you' : "@#{target_screen_name}"

      if result.relationship.source.following
        message = "#{source} following #{target}, ご主人様.\n"
      else
        message = "#{source} not following #{target}, ご主人様.\n"
      end

      source = source_screen_name == user.screen_name ? 'you' : "@#{source_screen_name}"
      target = target_screen_name == user.screen_name ? "You're" : "@#{target_screen_name} is"

      if result.relationship.target.following
        message << "#{target} following #{source}, ご主人様."
      else
        message << "#{target} not following #{source}, ご主人様."
      end

      message
    end

    define_command :block, /\Ab\s+(\S+)\Z/i do |user, message, params|
      screen_name = params[1]

      TwiMeido.current_user.rest_api_client.blocks.create! :screen_name => screen_name
      "You're now blocking @#{screen_name}, ご主人様."
    end

    define_command :unblock, /\Aunb\s+(\S+)\Z/i do |user, message, params|
      screen_name = params[1]

      TwiMeido.current_user.rest_api_client.blocks.destroy! :screen_name => screen_name
      "You're no longer blocking @#{screen_name} now, ご主人様."
    end

    define_command :if_block, /\Aib\s+(\S+)\Z/i do |user, message, params|
      begin
        screen_name = params[1]

        TwiMeido.current_user.rest_api_client.blocks.exists? :screen_name => screen_name
        message = "You're blocking @#{screen_name}, ご主人様."
      rescue Grackle::TwitterError => error
        if error.status == 404
          message = "You're not blocking @#{screen_name}, ご主人様."
        else
          raise error
        end
      end

      message
    end

    define_command :report_spam, /\Aspam\s+(\S+)\Z/i do |user, message, params|
      screen_name = params[1]

      TwiMeido.current_user.rest_api_client.report_spam! :screen_name => screen_name
      "You have reported @#{screen_name} as spam, ご主人様."
    end
  end
end
