module TwiMeido
  module TweetCommand
    extend Command

    define_command :tweet, nil do |user, message|
      user.rest_api_client.statuses.update! :status => message.body.strip
      'Successfully tweeted, ご主人様.'
    end
  end
end
