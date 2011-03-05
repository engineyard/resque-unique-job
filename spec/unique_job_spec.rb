require 'resque'
require 'resque/plugins/unique_job'

class WhatHappened
  require 'tempfile'  
  def self.reset!
    @what_happened = Tempfile.new("what_happened")
  end
  def self.what_happened
    File.read(@what_happened.path)
  end
  def self.record(*event)
    @what_happened.write(event.to_s)
    @what_happened.flush
  end
end

class BaseJob

  def self.enqueue(*args)
    Resque.enqueue(self, *args)
  end

  def self.perform(*args)
    begin
      WhatHappened.record(self, args)
    rescue => e
      puts e.inspect
      puts e.backtrace.join("\n")
    end
  end

end

class BasicJob < BaseJob
  extend Resque::Plugins::UniqueJob
  @queue = :test

end

class DifferentJob < BaseJob
  extend Resque::Plugins::UniqueJob
  @queue = :test

end

class NotUniqueJob < BaseJob
  @queue = :test
end

class ShortExpiringJob < BaseJob
  extend Resque::Plugins::UniqueJob
  @queue = :test
  
  def self.unique_redis_expiration
    1
  end
end


describe Resque::Plugins::UniqueJob do
  before(:each) do
    WhatHappened.reset!
    Resque.redis.flushall
  end
  
  it "works for 1 job" do
    BasicJob.enqueue("foo", "bar")
    worker = Resque::Worker.new(:test)
    worker.work(0)
    WhatHappened.what_happened.should == "BasicJobfoobar"
  end

  describe "uniqueness" do

    it "cares about job class" do
      BasicJob.enqueue("foo", "bar")
      DifferentJob.enqueue("foo", "bar")
      worker = Resque::Worker.new(:test)
      worker.work(0)
      WhatHappened.what_happened.should == "BasicJobfoobarDifferentJobfoobar"
    end
    
    it "only enqueues the job once" do
      BasicJob.enqueue("foo", "bar")
      BasicJob.enqueue("foo", "bar")
      worker = Resque::Worker.new(:test)
      worker.work(0)
      WhatHappened.what_happened.should == "BasicJobfoobar"
    end
    
    it "re-enqueues after the job has been processed" do
      worker = Resque::Worker.new(:test)
      BasicJob.enqueue("foo", "bar")
      worker.work(0)
      BasicJob.enqueue("foo", "bar")
      worker.work(0)
      WhatHappened.what_happened.should == "BasicJobfoobarBasicJobfoobar"
    end

    it "doesn't make non unique jobs unique" do
      NotUniqueJob.enqueue("foo", "bar")
      NotUniqueJob.enqueue("foo", "bar")
      worker = Resque::Worker.new(:test)
      worker.work(0)
      WhatHappened.what_happened.should == "NotUniqueJobfoobarNotUniqueJobfoobar"
    end
    
    it "respects dequeue" do
      BasicJob.enqueue("foo", "bar")
      Resque.dequeue(BasicJob, "foo", "bar")
      BasicJob.enqueue("foo", "bar")
      worker = Resque::Worker.new(:test)
      worker.work(0)
      WhatHappened.what_happened.should == "BasicJobfoobar"
    end

    it "respects destroy dequeue all" do
      BasicJob.enqueue("foo", "bar")
      BasicJob.enqueue("bar", "baz")
      Resque.dequeue(BasicJob)
      BasicJob.enqueue("foo", "bar")
      worker = Resque::Worker.new(:test)
      worker.work(0)
      WhatHappened.what_happened.should == "BasicJobfoobar"
    end

    it "doesn't destroy too much" do
      BasicJob.enqueue("foo", "bar")
      DifferentJob.enqueue("foo", "bar")
      Resque.dequeue(BasicJob, "foo", "bar")
      # DifferentJob.enqueue("foo", "bar")
      worker = Resque::Worker.new(:test)
      worker.work(0)
      WhatHappened.what_happened.should == "DifferentJobfoobar"
    end
     
    it "expires the uniqueness key" do
      ShortExpiringJob.enqueue("foo", "bar")
      sleep 2
      ShortExpiringJob.enqueue("foo", "bar")
      worker = Resque::Worker.new(:test)
      worker.work(0)
      WhatHappened.what_happened.should == "ShortExpiringJobfoobarShortExpiringJobfoobar"
    end
    
  end

end
