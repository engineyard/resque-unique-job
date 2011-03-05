Resque.class_eval do

  def self.dequeue_with_unique_job(klass, *args)
    klass.destroy_matching_keys(queue_from_class(klass), args)
    dequeue_without_unique_job(klass, *args)
  end


  class << self
    alias_method :dequeue_without_unique_job, :dequeue
    alias_method :dequeue, :dequeue_with_unique_job
  end


end