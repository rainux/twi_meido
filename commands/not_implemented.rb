module TwiMeido
  module NotImplementedCommand
    extend Command

    define_command :not_implemented, /\A.*\Z/m do |user, message|
      'Not implemented, ご主人様.'
    end
  end
end
