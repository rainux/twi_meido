module TwiMeido
  module TimelineCommands
    extend Command

    define_command :retweet, /\Are\s+(\d+|[a-z]+)\Z/i do |user, message, params|
      id = params[1]

      id = user.fetch_tweet(id).id if is_short_id(id)
      TwitterClient.statuses.retweet!(:id => id)

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
        TwitterClient.statuses.update!(:status => text)

        <<-MESSAGE
Successfully retweeted #{tweet.user.screen_name}'s tweet #{tweet.id} with your comment, ご主人様.
        MESSAGE
      end
    end

    define_command :reply, /\A[@r]\s+(\d+|[a-z]+)\s+(.*)\Z/im do |user, message, params|
      id = params[1]
      status = params[2]

      in_reply_to_tweet = user.fetch_tweet(id)

      TwitterClient.statuses.update!(
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
      TwitterClient.statuses.update!(
        :status => "#{mentioned_users.join ' '} #{status}",
        :in_reply_to_status_id => in_reply_to_tweet.id
      )

      <<-MESSAGE
Successfully replied to all mentioned users of #{in_reply_to_tweet.user.screen_name}'s tweet #{in_reply_to_tweet.id}, ご主人様.
      MESSAGE
    end

    define_command :mentions, /\A[@r]\Z/ do |user, message|
      tweets = TwitterClient.statuses.mentions?
      tweets.collect! do |tweet|
        format_tweet(tweet)
      end

      tweets.reverse.join("\n")
    end

    define_command :direct_messages, /\Ad\Z/ do |user, message|
      tweets = TwitterClient.direct_messages?
      tweets.collect! do |tweet|
        <<-DM
#{tweet.sender.screen_name}: #{CGI.unescapeHTML(tweet.text)}
        DM
      end

      tweets.reverse.join("\n")
    end

    define_command :profile, /\A(?:me|profile(?:\s+(\S+))?)\Z/ do |user, message, params|
      screen_name = params[1] ? params[1] : user.screen_name
      tweets = TwitterClient.statuses.user_timeline?(:screen_name => screen_name)
      tweets.collect! do |tweet|
        format_tweet(tweet)
      end

      tweets.reverse.join("\n")
    end

    define_command :delete, /\Adel(?:\s+(\d+|[a-z]+))?\Z/i do |user, message, params|
      id = params[1]

      if id.nil?
        tweets = TwitterClient.statuses.user_timeline?(:screen_name => user.screen_name, :count => 1)
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

      tweet = TwitterClient.statuses.destroy!(:id => id)
      message << format_tweet(tweet)
    end

    define_command :show, /\Ashow\s+(\d+|[a-z]+)(\s+\d+)?\Z/i do |user, message, params|
      id = params[1]
      length = params[2].to_i
      length = 5 if length.zero?

      format_tweet(user.fetch_tweet(id), true, length)
    end
  end
end
