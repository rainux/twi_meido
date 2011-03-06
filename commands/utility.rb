module TwiMeido
  module UtilityCommand
    extend Command

    define_command :help, /\Ah(elp)?(!)?\Z/i do |user, message, params|
      h_not_allowed = !params[1]
      dont_panic = params[2]

      if h_not_allowed
        'H 的事情是不可以的！'
      elsif dont_panic
        "Don't panic!"
      else
        <<-HELP
* Send messages to me, I'll tweet them for you.
* Any messages begin with " "(space) or "-" character are treat as commands.
* Start use me by send " oauth" command to bind your Twitter account.
* Follow @TwiMeido for development news.

See http://code.google.com/p/twi-meido/wiki/README for informations about available commands.
        HELP
      end
    end
  end
end
