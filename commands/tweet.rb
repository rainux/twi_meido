module TwiMeido
  module TweetCommand
    extend Command

    define_command :tweet, nil do |user, message|
      if user.loc_on == 1
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
        access_token = OAuth::AccessToken.new(
          client,
          user.loc_oauth_token,
          user.loc_oauth_token_secret
        )
        loc = JSON.parse(access_token.get('https://www.googleapis.com/latitude/v1/currentLocation?granularity=best&key=' + AppConfig.google.access_key).body)
        lat = loc['data']['latitude']
        lon = loc['data']['longitude']
        TwiMeido.current_user.rest_api_client.statuses.update!(:status => message.body.strip, :lat => lat, :lon => lon)
        response = 'Successfully tweeted with location, ご主人様.'
      else
        TwiMeido.current_user.rest_api_client.statuses.update! :status => message.body.strip
        response = 'Successfully tweeted, ご主人様.'
      end

      response
    end
  end
end
