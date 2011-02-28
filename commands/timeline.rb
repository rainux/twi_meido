module TwiMeido
  module TimelineCommands
    extend Command

    define_command :retweet, /\Are\s+(\d+|[a-z]+)\Z/i do |user, message, params|
      id = params[1]

      id = user.fetch_tweet(id).id if is_short_id(id)
      TwiMeido.current_user.rest_api_client.statuses.retweet!(:id => id)

      <<-MESSAGE
Successfully retweeted tweet #{id}, ご主人様.
      MESSAGE
    end

    define_command :retweet_with_comment, /\Art\s+(\d+|[a-z]+)(?:\s+(.*))?\Z/im do |user, message, params|
      id = params[1]
      comment = params[2]

      tweet = user.fetch_tweet(id)

      text = "#{comment} RT @#{tweet.user.screen_name}: #{tweet.text}"
      length = ActiveSupport::Multibyte::Chars.new(text).normalize(:c).length

      case length
      when 141
        text = "#{comment}RT @#{tweet.user.screen_name}: #{tweet.text}"
        length -= 1
      when 142
        text = "#{comment}RT @#{tweet.user.screen_name} #{tweet.text}"
        length -= 2
      end

      if length > 140
        <<-MESSAGE
Your tweet has #{length} characters which has reached the 140 limitation, ご主人様.
        MESSAGE

      else
        TwiMeido.current_user.rest_api_client.statuses.update!(:status => text)

        <<-MESSAGE
Successfully retweeted #{tweet.user.screen_name}'s tweet #{tweet.id} with your comment, ご主人様.
        MESSAGE
      end
    end

    define_command :reply, /\A[@r]\s+(\d+|[a-z]+)\s+(.*)\Z/im do |user, message, params|
      id = params[1]
      status = params[2]

      in_reply_to_tweet = user.fetch_tweet(id)

      TwiMeido.current_user.rest_api_client.statuses.update!(
        :status => "@#{in_reply_to_tweet.user.screen_name} #{status}",
        :in_reply_to_status_id => in_reply_to_tweet.id
      )

      <<-MESSAGE
Successfully replied to #{in_reply_to_tweet.user.screen_name}'s tweet #{in_reply_to_tweet.id}, ご主人様.
      MESSAGE
    end

    define_command :reply_all, /\Ara\s+(\d+|[a-z]+)\s+(.*)\Z/im do |user, message, params|
      id = params[1]
      status = params[2]

      in_reply_to_tweet = user.fetch_tweet(id)

      mentioned_users = in_reply_to_tweet.text.scan(%r{@[0-9A-Za-z_]+})
      mentioned_users = mentioned_users.uniq.reject do |user|
        ["@#{in_reply_to_tweet.user.screen_name.downcase}", "@#{TwiMeido.current_user.screen_name.downcase}"].include?(user.downcase)
      end
      mentioned_users.unshift "@#{in_reply_to_tweet.user.screen_name}"
      TwiMeido.current_user.rest_api_client.statuses.update!(
        :status => "#{mentioned_users.join ' '} #{status}",
        :in_reply_to_status_id => in_reply_to_tweet.id
      )

      <<-MESSAGE
Successfully replied to all mentioned users of #{in_reply_to_tweet.user.screen_name}'s tweet #{in_reply_to_tweet.id}, ご主人様.
      MESSAGE
    end

    define_command :direct_message, /\Ad\s+(\S+)\s+(\S+)\Z/i do |user, message, params|
      screen_name = params[1]
      text = params[2]

      begin
        dm = TwiMeido.current_user.rest_api_client.direct_messages.new!(
          :screen_name => screen_name, :text => text
        )
        response = "DM successfully sent to @#{screen_name}, ご主人様."

      rescue Grackle::TwitterError => error
        case error.status
        when 403
          response = "Can't sent dm to @#{screen_name} since he/she is not following you, ご主人様."
        when 404
          response = "The user @#{screen_name} is not exists, ご主人様."
        end
      end

      response
    end

    define_command :home, /\Ahome\Z/i do |user, message|
      tweets = TwiMeido.current_user.rest_api_client.statuses.home_timeline? :include_entities => true
      tweets.collect! do |tweet|
        format_tweet(tweet)
      end

      tweets.reverse.join("\n")
    end

    define_command :mentions, /\A[@r]\Z/i do |user, message|
      tweets = TwiMeido.current_user.rest_api_client.statuses.mentions? :include_entities => true
      tweets.collect! do |tweet|
        format_tweet(tweet)
      end

      tweets.reverse.join("\n")
    end

    define_command :direct_messages, /\Ad\Z/i do |user, message|
      tweets = TwiMeido.current_user.rest_api_client.direct_messages?
      tweets.collect! do |tweet|
        <<-DM
#{tweet.sender.screen_name}: #{CGI.unescapeHTML(tweet.text)}
        DM
      end

      tweets.reverse.join("\n")
    end

    define_command :favorites, /\Afav\Z/i do |user, message|
      tweets = TwiMeido.current_user.rest_api_client.favorites? :include_entities => true
      tweets.collect! do |tweet|
        format_tweet(tweet)
      end

      tweets.reverse.join("\n")
    end

    define_command :profile, /\A(?:me|profile(?:\s+(\S+))?)\Z/i do |user, message, params|
      begin
        screen_name = params[1] ? params[1] : user.screen_name
        tweets = TwiMeido.current_user.rest_api_client.statuses.user_timeline?(:screen_name => screen_name)
        tweets.collect! do |tweet|
          format_tweet(tweet)
        end
        tweets = tweets.reverse.join("\n")
      rescue Grackle::TwitterError => error
        if error.status == 401
          tweets = "@#{screen_name} is protected, ご主人様."
        else
          raise error
        end

      tweets
    end

    define_command :delete, /\Adel(?:\s+(\d+|[a-z]+))?\Z/i do |user, message, params|
      id = params[1]

      if id.nil?
        tweets = TwiMeido.current_user.rest_api_client.statuses.user_timeline?(:screen_name => user.screen_name, :count => 1)
        id = tweets.first.id
        message = <<-MESSAGE
Successfully deleted your latest tweet.

        MESSAGE
      else
        id = user.fetch_tweet(id).id
        message = <<-MESSAGE
Successfully deleted your tweet #{id}.

        MESSAGE
      end

      tweet = TwiMeido.current_user.rest_api_client.statuses.destroy!(:id => id)
      message << format_tweet(tweet)
    end

    define_command :show, /\Ashow\s+(\d+|[a-z]+)(\s+\d+)?\Z/i do |user, message, params|
      id = params[1]
      length = params[2].to_i
      length = 5 if length.zero?

      format_tweet(user.fetch_tweet(id), true, length)
    end

    define_command :favorite, /\Afav\s+(\d+|[a-z]+)\Z/i do |user, message, params|
      id = params[1]

      id = user.fetch_tweet(id).id if is_short_id(id)
      TwiMeido.current_user.rest_api_client.favorites.create!(:id => id)

      "Successfully favorited tweet #{id}, ご主人様."
    end

    define_command :unfavorite, /\Aunfav\s+(\d+|[a-z]+)\Z/i do |user, message, params|
      id = params[1]

      id = user.fetch_tweet(id).id if is_short_id(id)
      TwiMeido.current_user.rest_api_client.favorites.destroy!(:id => id)

      "Successfully unfavorited tweet #{id}, ご主人様."
    end
  end
end
