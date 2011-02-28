module TwiMeido
  module LocationCommands
    extend Command

    define_command :loc_oauth, /\Aloc\s+oauth\Z/i do |user, message|
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
        :loc_request_token => request_token.token,
        :loc_request_token_secret => request_token.secret
      )

      <<-MESSAGE
Please visit the following URL to confirm your OAuth request:
#{request_token.authorize_url}&domain=jimmyxu.org&granularity=best
After that you'll get a PIN code, use it with -loc bind command to complete the OAuth process like this:
-loc bind PIN_CODE
      MESSAGE
    end

    define_command :loc_bind, /\Aloc\s+bind\s+(.+)\Z/i do |user, message, params|
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
          user.loc_request_token,
          user.loc_request_token_secret
        )
        access_token = request_token.get_access_token(
          :oauth_verifier => params[1]
        )
        user.update_attributes(
          :loc_oauth_token => access_token.token,
          :loc_oauth_token_secret => access_token.secret
        )

        response = <<-MESSAGE
Successfully bound your Google Latitude, use -loc on to send tweets with location, ご主人様.
        MESSAGE

      rescue OAuth::Unauthorized
        response = 'OAuth with Latitude failed, please retry by use -loc oauth command, ご主人様.'
      end

      response
    end

    define_command :loc_switch, /\Aloc\s+(on|off)\Z/i do |user, message, params|
      if user.loc_oauth_token == nil or user.loc_oauth_token_secret == nil
        response = 'Please run -loc oauth first, ご主人様.'
      elsif params[1] == 'on'
        user.update_attributes :loc_on => 1
        response = 'Location turned on, ご主人様.'
      else
        user.update_attributes :loc_on => 0
        response = 'Location turned off, ご主人様.'
      end

      response
    end
  end
end
