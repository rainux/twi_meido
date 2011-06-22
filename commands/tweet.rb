module TwiMeido
  module TweetCommand
    extend Command

    define_command :tweet, nil do |user, message|
      TwiMeido.current_user.update_status! :status => message.strip
      'Successfully tweeted, ご主人様.'
    end
  end
end
