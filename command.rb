module TwiMeido
  module Command
    include ActionView::Helpers::DateHelper
    include ActionView::Helpers::NumberHelper

    def define_command(name, pattern, &block)
      puts "Command registered: #{name}"
      @@commands ||= []
      @@commands << Hashie::Mash.new(
        :name => name,
        :pattern => pattern,
        :action => block
      )
    end

    def process_message(user, message)
      @@commands ||= []
      @@commands.each do |command|
        match = message.body.strip.match(command.pattern)
        if match
          begin
            if match.captures.empty?
              return command.action.call(user, message)
            else
              return command.action.call(user, message, match)
            end

          rescue => error
            return "#{extract_error_message(error)}, ご主人様."
          end
        end
      end
    end

    private
    def extract_error_message(error)
      if error.respond_to? :response_body
        begin
          response_body = Hashie::Mash.new(JSON.parse(error.response_body))
        rescue
          return 'Big whale flying'
        end
        if response_body.errors
          message = response_body.errors.collect(&:message).join("\n")
        elsif response_body.error
          message = response_body.error
        end
      else
        message = error.message
      end
      message
    end

    def format_tweet(tweet, short_id = nil)

      if tweet.retweeted_status
        <<-TWEET
#{tweet.retweeted_status.user.screen_name}: #{CGI.unescapeHTML(tweet.retweeted_status.text)}
[ #{id_info(tweet.retweeted_status, short_id)} #{time_info(tweet.retweeted_status)}via #{strip_tags(tweet.retweeted_status.source)} ]
[ Retweeted by #{tweet.user.screen_name} #{time_info(tweet)}via #{strip_tags(tweet.source)} ]
        TWEET

      elsif tweet.user
        <<-TWEET
#{tweet.user.screen_name}: #{CGI.unescapeHTML(tweet.text)}
[ #{id_info(tweet, short_id)} #{time_info(tweet)}via #{strip_tags(tweet.source)} ]
        TWEET

      elsif tweet.direct_message
        dm = tweet.direct_message
        <<-TWEET
DM from #{dm.sender.screen_name} (#{dm.sender.name}):
#{CGI.unescapeHTML(dm.text)}
        TWEET

      else
        <<-TWEET
#{tweet.inspect}
        TWEET
      end
    end

    def format_event(event)
      case event.event
      when 'follow'
        <<-EVENT
@#{event.source.screen_name} is now following @#{event.target.screen_name}.

#{format_profile(event.source, false).chomp}
        EVENT

      when 'favorite'
        <<-EVENT
@#{event.source.screen_name} favorited @#{event.target.screen_name}'s tweet #{event.target_object.id}.

#{format_tweet(event.target_object).chomp}
        EVENT

      when 'unfavorite'
        <<-EVENT
@#{event.source.screen_name} unfavorited @#{event.target.screen_name}'s tweet #{event.target_object.id}.

#{format_tweet(event.target_object).chomp}
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
      id < 1000
    end

    def id_info(tweet, short_id)
      if short_id
        "ID: #{short_id} << #{tweet.id}"
      else
        "ID: #{tweet.id}"
      end
    end

    def time_info(tweet)
      if Time.parse(tweet.created_at) < 1.minute.ago
        "#{time_ago_in_words(tweet.created_at)} ago "
      end
    end
  end

  extend Command
end
