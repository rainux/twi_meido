module TwiMeido
  module RepeatCommand
    extend Command

    define_command :repeat, /\A!!\Z/i do |user, message|
      process_message(user, user.last_said)
    end
  end
end
