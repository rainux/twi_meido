module TwiMeido
  module LocationCommands
    extend Command

    define_command :latitude_oauth, /\Alatitude\s+oauth\Z/i do |user, message|
      client = OAuth::Consumer.new(
        AppConfig.google.consumer_key,
        AppConfig.google.consumer_secret,
        { :site => 'https://www.google.com',
          :request_token_path => '/accounts/OAuthGetRequestToken',
          :access_token_path => '/accounts/OAuthGetAccessToken',
          :authorize_path => '/latitude/apps/OAuthAuthorizeToken',
          :signature_method => 'HMAC-SHA1'
        }
      )
      request_token = client.get_request_token({},
        :scope => 'https://www.googleapis.com/auth/latitude'
      )
      user.update_attributes(
        :latitude_request_token => request_token.token,
        :latitude_request_token_secret => request_token.secret
      )

      <<-MESSAGE
Please visit the following URL to confirm your OAuth request:
#{Googl.shorten(request_token.authorize_url + '&domain=' + AppConfig.google.domain + '&granularity=best').short_url}
After that you'll get a PIN code, use it with -latitude bind command to complete the OAuth process like this:
-latitude bind PIN_CODE
      MESSAGE
    end

    define_command :latitude_bind, /\Alatitude\s+bind\s+(.+)\Z/i do |user, message, params|
      begin
        client = OAuth::Consumer.new(
          AppConfig.google.consumer_key,
          AppConfig.google.consumer_secret,
          { :site => 'https://www.google.com',
            :request_token_path => '/accounts/OAuthGetRequestToken',
            :access_token_path => '/accounts/OAuthGetAccessToken',
            :authorize_path => '/latitude/apps/OAuthAuthorizeToken',
            :signature_method => 'HMAC-SHA1'
          }
        )
        request_token = OAuth::RequestToken.new(
          client,
          user.latitude_request_token,
          user.latitude_request_token_secret
        )
        access_token = request_token.get_access_token(
          :oauth_verifier => params[1]
        )
        user.update_attributes(
          :latitude_oauth_token => access_token.token,
          :latitude_oauth_token_secret => access_token.secret
        )

        response = <<-MESSAGE
Successfully bound your Google Latitude, use -latitude on to send tweets with latitudeation, ご主人様.
        MESSAGE

      rescue OAuth::Unauthorized
        response = 'OAuth with Google Latitude failed, please retry by use -latitude oauth command, ご主人様.'
      end

      response
    end

    define_command :latitude_switch, /\Alatitude\s+(on|off)\Z/i do |user, message, params|
      if user.latitude_oauth_token == nil or user.latitude_oauth_token_secret == nil
        response = 'Please run -latitude oauth first, ご主人様.'
      elsif params[1] == 'on'
        user.update_attributes :latitude_on => 1
        response = 'Latitude location turned on, ご主人様.'
      else
        user.update_attributes :latitude_on => 0
        response = 'Latitude location turned off, ご主人様.'
      end

      response
    end
  end
end
