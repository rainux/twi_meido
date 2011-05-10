module TwiMeido
  module Version
    MAJOR = 0
    MINOR = 1
    PATCH = 0
    BUILD = nil

    STRING = [MAJOR, MINOR, PATCH, BUILD].compact.join('.')

    def self.to_s
      STRING
    end
  end
end
