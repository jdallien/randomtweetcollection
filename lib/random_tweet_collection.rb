class RandomTweetCollection
  # 200 is max number of tweets permitted by Twitter API
  MAX_TWEETS = 200

  def initialize(username, cache_duration = 15.minutes)
    @username       = username
    @cache_duration = cache_duration
    @client         = Twitter::Client.new
  end

  def tweets(count = 5)
    if count > MAX_TWEETS
      raise ArgumentError, "Requested number of tweets can't exceed MAX_TWEETS (#{MAX_TWEETS})"
    end
    refresh_cache_if_stale
    returning([]) do |tweet_array|
      random_tweet_positions(count).each do |position|
        tweet_array << @timeline[position]
      end
    end
  end

  def refresh_tweets
    Rails.cache.delete(expire_time_cache_key)
    refresh_cache_if_stale
  end

  private

  def timeline_cache_key
    "twitter_timeline_#{@username}"
  end

  def expire_time_cache_key
    "twitter_timeline_expiry_#{@username}"
  end

  def refresh_cache_if_stale
    cache_expiry = Rails.cache.read(expire_time_cache_key)
    unless cache_expiry && cache_expiry > Time.now
      Rails.cache.delete(timeline_cache_key) 
      Rails.cache.write(expire_time_cache_key, Time.now + @cache_duration)
    end
    @timeline = Rails.cache.fetch(timeline_cache_key) { update_twitter_timeline }
  end

  def update_twitter_timeline
    @client.timeline_for(:user,
                         :id    => @username,
                         :count => MAX_TWEETS)
  end

  def random_tweet_positions(count)
    (0..(MAX_TWEETS - 1)).to_a.sort{ rand() - 0.5 }[0..(count - 1)]
  end
end
