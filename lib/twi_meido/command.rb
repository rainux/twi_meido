module TwiMeido
  module Command
    include ActionView::Helpers::DateHelper
    include ActionView::Helpers::NumberHelper

    CommandLeaderRegex = /\A(?:\s+|\s*-)/

    def define_command(name, pattern, &block)
      puts "Command registered: #{name}"
      @@commands ||= []
      if pattern
        @@commands << Hashie::Mash.new(
          :name => name,
          :pattern => pattern,
          :action => block
        )
      else
        @@default_command = Hashie::Mash.new(
          :name => name,
          :action => block
        )
      end
    end

    def process_message(user, message)
      message = message.body.rstrip if message.respond_to? :body
      result = ''
      # XXX: Workaround for ``stack level too deep''
      user.last_said = message unless message =~ /#{CommandLeaderRegex}!!\Z/
      user.save
      if message =~ CommandLeaderRegex
        @@commands.each do |command|
          match = message.lstrip.gsub(CommandLeaderRegex, '').match(command.pattern)
          if match
            if match.captures.empty?
              result = command.action.call(user, message)
            else
              result = command.action.call(user, message, match)
            end
            break
          end
        end
      else
        result = @@default_command.action.call(user, message)
      end

      result

    rescue => error
      if error.kind_of?(Grackle::TwitterError) && error.status == 401
        return <<-HELP
* Start use me by send -oauth command to bind your Twitter account.
* Send -help command for detailed help.
        HELP
      else
        return "#{extract_error_message(error)}, ご主人様."
      end
    end

    private
    def unescape(str)
      str.gsub('&lt;', '<').gsub('&gt;', '>')
    end

    def extract_error_message(error)
      if error.respond_to? :response_body
        begin
          response_body = Hashie::Mash.new(JSON.parse(error.response_body))
        rescue
          return 'Big whale flying'
        end
        if response_body.errors
          if response_body.errors.kind_of?(Array)
            message = response_body.errors.collect(&:message).join("\n")
          else
            message = response_body.errors
          end
        elsif response_body.error
          message = response_body.error
        end
      else
        message = error.message
      end
      message
    end

    def format_tweet(tweet, shorten_id = true, conversation_length = 1, location = false)
      conversation = load_conversation(tweet, shorten_id, conversation_length)
      if conversation
        conversation = conversation.flatten.compact.join("\n")
        conversation = <<-CONVERSATION

┌────────────
#{conversation.gsub(/^/m, '│ ').chomp}
└────────────
        CONVERSATION
        conversation.chomp!
      end
      formatted_tweet = format_single_tweet(tweet, shorten_id, conversation, location)
    end

    def load_conversation(tweet, shorten_id = true, conversation_length = 5)
      if tweet.in_reply_to_status_id && conversation_length > 0
        in_reply_to_tweet = Tweet.fetch(tweet.in_reply_to_status_id)
        if in_reply_to_tweet
          conversation = [format_single_tweet(in_reply_to_tweet, shorten_id)]
          conversation << load_conversation(in_reply_to_tweet, shorten_id, conversation_length - 1)
        end
      end
    end

    def format_single_tweet(tweet, shorten_id = true, conversation = nil, location = false)

      if tweet.retweeted_status.present?
        formatted_tweet = <<-TWEET
#{tweet.retweeted_status.user.screen_name}: #{unescape(tweet.retweeted_status.text)}#{conversation}
[ #{id_info(tweet.retweeted_status, shorten_id)} | #{time_info(tweet.retweeted_status)}via #{strip_tags(tweet.retweeted_status.source)} #{'[GEO] ' if tweet.retweeted_status.geo.present?}]
[ #{id_info(tweet, shorten_id)} | Retweeted by #{tweet.user.screen_name} #{time_info(tweet)}via #{strip_tags(tweet.source)} #{'[GEO] ' if tweet.geo.present?}]
        TWEET

      elsif tweet.user.present?
        formatted_tweet = <<-TWEET
#{tweet.user.screen_name}: #{unescape(tweet.text)}#{conversation}
[ #{id_info(tweet, shorten_id)} | #{time_info(tweet)}via #{strip_tags(tweet.source)} #{'[GEO] ' if tweet.geo.present?}]
        TWEET

      else
        formatted_tweet = <<-TWEET
#{tweet.inspect}
        TWEET
      end

      if location
        if tweet.geo.present?
          reverse = Geokit::Geocoders::GoogleGeocoder.reverse_geocode "#{tweet.geo['coordinates'][0]},#{tweet.geo['coordinates'][1]}"
        elsif tweet.retweeted_status.geo.present?
          reverse = Geokit::Geocoders::GoogleGeocoder.reverse_geocode "#{tweet.retweeted_status.geo['coordinates'][0]},#{tweet.retweeted_status.geo['coordinates'][1]}"
        end
        formatted_tweet += "[ Sent from #{reverse.full_address}. ]" if reverse
      end
      formatted_tweet
    end

    def format_event(event)
      case event.event
      when 'follow'
        if event.source.screen_name == TwiMeido.current_user.screen_name
          user = event.target
        else
          user = event.source
        end
        <<-EVENT
@#{event.source.screen_name} is now following @#{event.target.screen_name}.

#{format_profile(user, false)}
        EVENT

      when 'favorite'
        <<-EVENT
@#{event.source.screen_name} favorited @#{event.target.screen_name}'s tweet #{event.target_object.id}.

#{format_tweet(event.target_object)}
        EVENT

      when 'unfavorite'
        <<-EVENT
@#{event.source.screen_name} unfavorited @#{event.target.screen_name}'s tweet #{event.target_object.id}.

#{format_tweet(event.target_object)}
        EVENT

      when 'block'
        <<-EVENT
@#{event.source.screen_name} blocked @#{event.target.screen_name}.
        EVENT

      when 'unblock'
        <<-EVENT
@#{event.source.screen_name} unblocked @#{event.target.screen_name}.
        EVENT

      when 'list_member_added'
        <<-EVENT
@#{event.source.screen_name} added @#{event.target.screen_name} to list #{event.target_object.full_name}.

#{event.target_object.full_name}
#{event.target_object.description.blank? ? '(No description)' : event.target_object.description}
        EVENT

      when 'list_member_removed'
        <<-EVENT
@#{event.source.screen_name} removed @#{event.target.screen_name} from list #{event.target_object.full_name}.

#{event.target_object.full_name}
#{event.target_object.description.blank? ? '(No description)' : event.target_object.description}
        EVENT
      end
    end

    def format_dm(dm, shorten_id = true)
      TwiMeido.current_user.view_dm!(dm)

      formatted_dm = <<-DM
DM from #{dm.sender.screen_name} (#{dm.sender.name}):
#{unescape(dm.text)}
[ #{dm_id_info(dm, shorten_id)} ]
      DM
    end

    def format_profile(user, with_stats = true)
      profile = <<-PROFILE
#{user.name}
@#{user.screen_name}#{user.location.blank? ? '' : " #{user.location}"}
      PROFILE
      profile << user.description << "\n" unless user.description.blank?
      profile << user.url << "\n" unless user.url.blank?

      profile << <<-STATS if with_stats
Following: #{number_with_delimiter(user.friends_count)}
Followers: #{number_with_delimiter(user.followers_count)}
Tweets: #{number_with_delimiter(user.statuses_count)}
Joined: #{Time.parse(user.created_at).to_date.to_s :long_ordinal}
Tweets per day: #{'%.2f' % (user.statuses_count.to_f / (Time.now.to_date - Time.parse(user.created_at).to_date).to_f)}
      STATS
      profile
    end

    def strip_tags(text)
      text.gsub /<[^>]+>/, ''
    end

    def is_short_id(id)
      if id.respond_to?(:is_valid_b26?) && id.is_valid_b26?
        id = id.as_b26_to_i
      else
        id = id.to_i
      end
      id < 1000
    end

    def id_info(tweet, shorten_id)
      if shorten_id
        short_id = TwiMeido.current_user.view_tweet!(tweet)
        "##{short_id.to_b26} = ##{short_id}"
      else
        "##{tweet.id.to_b26} = ##{tweet.id}"
      end
    end

    def dm_id_info(dm, shorten_id)
      if shorten_id
        short_id = TwiMeido.current_user.view_dm!(dm)
        "##{short_id.to_b26} = ##{short_id}"
      else
        "##{tweet.id.to_b26} = ##{tweet.id}"
      end
    end

    def time_info(tweet)
      if Time.parse(tweet.created_at) < 1.minute.ago
        "#{time_ago_in_words(tweet.created_at)} ago "
      end
    end

    def extract_notification(item)
      if item.friends
        update_friends(item)
      elsif item.entities
        extract_unread_tweet(item)
      elsif (item.event || item[:delete])
        extract_event(item)
      elsif item.direct_message
        extract_unread_dm(item.direct_message)
      end
    end

    def update_friends(friends)
      current_user.friends_ids = friends.friends
      current_user.friends_ids += [current_user.twitter_user_id]
      current_user.friends_ids.uniq!
      current_user.save

      nil
    end

    def extract_unread_tweet(tweet)
      if !current_user.filtered?(tweet) &&
        ((current_user.notification.include?(:home) && current_user.home_common?(tweet)) ||
        (current_user.notification.include?(:mention) && current_user.mentioned_by?(tweet)) ||
        (current_user.notification.include?(:track) && current_user.tracking?(tweet)))

        unless current_user.viewed_tweet_ids.include?(tweet.id)
          User.create_or_update_from_tweet(tweet)
          unless current_user.blocked_user_ids.include?(tweet.user.id) ||
            (tweet.retweeted_status.present? && (current_user.blocked_user_ids.include?(tweet.retweeted_status.user.id) || current_user.viewed_tweet_ids.include?(tweet.retweeted_status.id)))

            format_tweet(tweet)
          end
        end
      end
    end

    def extract_event(event)
      if event.source.present? && event.source.screen_name == current_user.screen_name
        if event.event == 'follow' # TODO: unfollow?
          current_user.friends_ids += [event.target.id]
          current_user.friends_ids.uniq!
          current_user.save
        elsif event.event == 'block'
          current_user.blocked_user_ids += [event.target.id]
          current_user.blocked_user_ids.uniq!
          current_user.save
        elsif event.event == 'unblock'
          current_user.blocked_user_ids -= [event.target.id]
          current_user.blocked_user_ids.uniq!
          current_user.save
        end
      end
      if current_user.notification.include?(:event)
        format_event(event)
      end
    end

    def extract_unread_dm(dm)
      if current_user.notification.include?(:dm) && dm.sender.screen_name != current_user.screen_name
        unless current_user.viewed_dm_ids.include?(dm.id)

          unless current_user.last_dm_id
            current_user.update_attributes(:last_dm_id => dm.id)
          end

          format_dm(dm)
        end
      end
    end
  end

  extend Command
end
