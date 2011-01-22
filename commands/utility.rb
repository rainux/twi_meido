module TwiMeido
  module UtilityCommand
    extend Command

    define_command :help, /\A-h(elp)?(!)?\Z/ do |user, message, params|
      h_not_allowed = !params[1]
      dont_panic = params[2]

      if h_not_allowed
        'H 的事情是不可以的！'
      elsif dont_panic
        "Don't panic!"
      else
        <<-HELP
* Send messages to me, I'll tweet them for you.
* Any messages begin with "-" character are treat as commands.
* Start use me by send -oauth command to bind your Twitter account.
* Follow @TwiMeido for development news.

Available commands:

-oauth
Start an OAuth process to bind your Twitter account.

-bind PIN_CODE
Use the PIN code you've got from -oauth command to actually bind your Twitter account.

-on [notification_type]
Turn on a specified type of real-time notification.
Run without parameter to show available notification types and current status.

-off [notification_type]
Turn off a specified type of real-time notification.
Run without parameter to get available notification types and current status.

-track [keywords]
Add keywords to tracking keyword list, keywords are delimited by space.
Run without parameter to show currently tracking keywords.
You can control real-time notification for tracked keywords by `-on track` and `-off track` command.
CAUTION: Never track very hot keywords like "Twitter", "is", "awesome", etc.

-untrack [keywords]
Add keywords to tracking keyword list, keywords are delimited by space.
Run without parameter to show currently tracking keywords.
You can control real-time notification for tracked keywords by `-on track` and `-off track` command.

-reset
Reset short id to #A. Short id will be reset automatically when it reaches #BMM.
I will generate short id for any tweets you've viewed like this: [ ID: #BZ ... ].
The short id is a base-26 number which represent by letters A-Z.
You can use short id with any commands that require a tweet id parameter (without the "#" character), it's case insensitive.

-fo username
Follow the specified user.

-unfo username
Unfollow the specified user.

-if username
Show follow relationship between the specified user and you.

-re tweet_id
Retweet the specified tweet, this is the "official retweet".

-rt tweet_id [comment]
Retweet the specified tweet with your comment.

-r tweet_id text
-@ tweet_id text
Reply the specified tweet with the text.

-ra tweet_id text
Reply the specified tweet with the text, and mention all users mentioned by the original tweet.

-@
Show the tweets mentioned you.

-d
Show the direct messages sent to you.

-me
Show your tweets.

-profile [username]
Show the specified user's tweets.

-del [tweet_id]
Delete the specified tweet of yours.
Run without parameter will delete the latest tweet.

-show tweet_id [conversation_length]
Show the specified tweet, with conversation if available.
Conversation length default to 5.

-help
Show this help.
        HELP
      end
    end
  end
end
