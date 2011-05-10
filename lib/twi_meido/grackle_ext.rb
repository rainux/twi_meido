module Grackle
  module Handlers
    class JSON2MashHandler
      def decode_response(res)
        json_result = JSON.parse(res)
        if json_result.respond_to?(:each_pair)
          Hashie::Mash.new(json_result)
        elsif json_result.respond_to?(:collect)
          json_result.collect {|item| Hashie::Mash.new(item) }
        else
          raise "Unexpected Response: #{res}"
        end
      end
    end
  end
end
