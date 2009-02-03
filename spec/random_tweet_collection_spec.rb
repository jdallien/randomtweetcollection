require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'config', 'boot.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'config', 'environment.rb'))

describe RandomTweetCollection, "retrieving tweets from Twitter" do
  before :each do
    @username         = 'TWITTER_USERNAME'
    @twitter4r_client = mock("Twitter4r client")
    Twitter::Client.stub!(:new).and_return(@twitter4r_client)
    @all_tweets       = 200.times.map{ |i| Twitter::Status.new(:id => i) }
    @collection       = RandomTweetCollection.new(@username, 30.minutes)
    Rails.cache.delete("twitter_timeline_expiry_#{@username}")
    Rails.cache.delete("twitter_timeline_#{@username}")
  end

  it "should load the most recent tweets" do
    @twitter4r_client.
      should_receive(:timeline_for).
        with(:user,
             :id    => @username,
             :count => RandomTweetCollection::MAX_TWEETS).and_return([])
    @collection.tweets
  end

  describe "returning a random selection of tweets" do
    before :each do
      @twitter4r_client.stub!(:timeline_for).and_return(@all_tweets)
    end

    it "should return an array the same size as requested" do
      @collection.tweets(8).size.should == 8
    end

    it "should default to a set of 5 tweets with no count given" do
      @collection.tweets.size.should == 5
    end

    it "should raise an error if too many tweets are requested" do
      lambda {
        @collection.tweets(RandomTweetCollection::MAX_TWEETS + 1)
      }.should raise_error
    end

    it "should choose the set of tweets randomly" do
      srand(1) # make random numbers not random for testing
      @collection.tweets.map(&:id).should == [87, 193, 153, 90, 80]
    end
  end
 
  describe RandomTweetCollection, "caching the results from Twitter" do
    before :each do
      @twitter4r_client.should_receive(:timeline_for).and_return(@all_tweets)
      Time.stub!(:now).and_return(Time.parse("01/01/09 00:00:00")) 
    end

    it "should put the twitter results in the cache" do
      @collection.tweets
      Rails.cache.read("twitter_timeline_#{@username}").should == @all_tweets
    end

    it "should store a twitter cache expiry time" do
      @collection.tweets
      expiry_time = Time.parse("01/01/09 00:30:00")
      Rails.cache.read("twitter_timeline_expiry_#{@username}").should == expiry_time
    end

    it "should clear the cache when the expiry time has passed" do
      @collection.tweets
      Time.stub!(:now).and_return(Time.parse("01/01/09 00:31:00"))
      Rails.cache.should_receive(:delete).with("twitter_timeline_#{@username}")
      @collection.tweets 
    end
    
    it "should not clear the cache when the expiry time has not passed" do
      @collection.tweets
      Time.stub!(:now).and_return(Time.parse("01/01/09 00:01:00"))
      Rails.cache.should_not_receive(:delete)
      @collection.tweets
    end
  end
end


