resque-unique-job
===============
Depends on [Resque](http://github.com/defunkt/resque/) 1.8

About
-----
This is a gem that will prevent multiple of the same job being enqueued
with resque.

It works by overriding the JobClass.enqueue method so you need to define a base
class that defines self.enqueue before extending the plugin.

Examples
--------

    class BaseJob
      def self.enqueue(*args)
        Resque.enqueue(self, *args)
      end
    end

    class MyJob < BaseJob
      extend Resque::Plugins::UniqueJob

      def self.perform(*args)
        #do stuff
      end
    end



Requirements
------------
* [resque](http://github.com/defunkt/resque/) 1.8
