module TwiMeido
  module TweetCommand
    extend Command

    define_command :tweet, nil do |user, message|
      text = message.strip
      length = ActiveSupport::Multibyte::Chars.new(text).normalize(:c).length

      # FIXME: Place this in a class and freeze it.
      # Stolen from Twitter::Regex
      url_regex = /(((?i-mx:[^-\/"':!=A-Z0-9_@\357\274\240]|^|\:))
        (
          (https?:\/\/)
          ((?i-mx:(?-mix:(?:[^[:punct:]\s](?:[_-]|[^[:punct:]\s])*)?[^[:punct:]\s]\.)*(?-mix:(?:[^[:punct:]\s](?:[-]|[^[:punct:]\s])*)?[^[:punct:]\s])\.[a-z]{2,}(?::[0-9]+)?))
          (\/
            (?:
              (?ix-m:
      (?i-mx:\((?i-mx:[a-z0-9!\*';:=\+\,\$\/%#\[\]\-_~|\.])+\))|
      @(?i-mx:[a-z0-9!\*';:=\+\,\$\/%#\[\]\-_~|\.])+\/|
      [\.,](?i-mx:[a-z0-9!\*';:=\+\,\$\/%#\[\]\-_~|\.])+|
      (?i-mx:[a-z0-9!\*';:=\+\,\$\/%#\[\]\-_~|\.])+
    )+(?i-mx:[a-z0-9=_#\/\+\-]|(?i-mx:\((?i-mx:[a-z0-9!\*';:=\+\,\$\/%#\[\]\-_~|\.])+\)))|
              (?ix-m:
      (?i-mx:\((?i-mx:[a-z0-9!\*';:=\+\,\$\/%#\[\]\-_~|\.])+\))|
      @(?i-mx:[a-z0-9!\*';:=\+\,\$\/%#\[\]\-_~|\.])+\/|
      [\.,](?i-mx:[a-z0-9!\*';:=\+\,\$\/%#\[\]\-_~|\.])+|
      (?i-mx:[a-z0-9!\*';:=\+\,\$\/%#\[\]\-_~|\.])+
    )+(?i-mx:[a-z0-9=_#\/\+\-]|(?i-mx:\((?i-mx:[a-z0-9!\*';:=\+\,\$\/%#\[\]\-_~|\.])+\)))?|
              (?i-mx:[a-z0-9=_#\/\+\-]|(?i-mx:\((?i-mx:[a-z0-9!\*';:=\+\,\$\/%#\[\]\-_~|\.])+\)))
            )?
          )?
          (\?(?i-mx:[a-z0-9!\*'\(\);:&=\+\$\/%#\[\]\-_\.,~|])*(?i-mx:[a-z0-9_&=#\/]))?
        )
      )
    /ix

      if length > 140
        text.gsub(url_regex) do
          $2 + Googl.shorten($3).short_url
        end
      end

      TwiMeido.current_user.update_status! :status => text
      'Successfully tweeted, ご主人様.'
    end
  end
end
