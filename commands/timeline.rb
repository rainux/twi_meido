module TwiMeido
  module TimelineCommands
    extend Command

    define_command :retweet, /^-re\s*(\d+)$/ do |user, message, params|
      id = params[1].to_i

      id = user.viewed_tweet(id).id if is_short_id(id)
      TwitterClient.statuses.retweet!(:id => id)

      <<-MESSAGE
Successfully retweeted tweet #{id}, ご主人様.
      MESSAGE
    end

    define_command :retweet_with_comment, /^-rt\s*(\d+)\s*(.*)$/ do |user, message, params|
      id = params[1].to_i
      comment = params[2]

      if is_short_id(id)
        tweet = user.viewed_tweet(id)
      else
        tweet = TwitterClient.statuses.show._(id).json?
      end

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

    define_command :reply, /^-[@r]\s*(\d+)\s*(.*)$/ do |user, message, params|
      id = params[1].to_i
      status = params[2]

      if is_short_id(id)
        in_reply_to_tweet = user.viewed_tweet(id)
      else
        in_reply_to_tweet = TwitterClient.statuses.show._(id).json?
      end

      TwitterClient.statuses.update!(
        :status => "@#{in_reply_to_tweet.user.screen_name} #{status}",
        :in_reply_to_status_id => in_reply_to_tweet.id
      )

      <<-MESSAGE
Successfully replied to #{in_reply_to_tweet.user.screen_name}'s tweet #{in_reply_to_tweet.id}, ご主人様.
      MESSAGE
    end

    define_command :reply_all, /^-ra\s*(\d+)\s*(.*)$/ do |user, message, params|
      id = params[1].to_i
      status = params[2]

      if is_short_id(id)
        in_reply_to_tweet = user.viewed_tweet(id)
      else
        in_reply_to_tweet = TwitterClient.statuses.show._(id).json?
      end

      mentioned_users = in_reply_to_tweet.text.scan(%r{@[0-9A-Za-z_]+})
      mentioned_users = mentioned_users.uniq.reject do |user|
        ["@#{in_reply_to_tweet.user.screen_name.downcase}", '@rainux'].include?(user.downcase)
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

    define_command :mentions, /^-@$/ do |user, message|
      tweets = TwitterClient.statuses.mentions?
      tweets.collect! do |tweet|
        format_tweet(tweet, user.view_tweet!(tweet))
      end

      tweets.reverse.join("\n")
    end

    define_command :direct_messages, /^-d$/ do |user, message|
      tweets = TwitterClient.direct_messages?
      tweets.collect! do |tweet|
        <<-DM
#{tweet.sender.screen_name}: #{CGI.unescapeHTML(tweet.text)}
        DM
      end

      tweets.reverse.join("\n")
    end
  end
end
