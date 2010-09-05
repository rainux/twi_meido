module TwiMeido
  module Command
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
        response_body = Hashie::Mash.new(JSON.parse(error.response_body))
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
  end

  extend Command
end
