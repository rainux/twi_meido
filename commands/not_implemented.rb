module TwiMeido
  module NotImplementedCommand
    extend Command

    define_command :not_implemented, /^-.*$/ do |message|
      'Not implemented, ご主人様.'
    end
  end
end
