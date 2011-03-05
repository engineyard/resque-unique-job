require 'resque/plugins/resque_ext/destroy'

module Resque
  module Plugins
    module UniqueJob
      include Resque::Helpers

      def enqueue(*args)
        key = unique_redis_key(args)
        ttl = Resque.redis.ttl(key)
        # if it's already enQ'd
        if Resque.redis.getset(key, "1")
          if expire = unique_redis_expiration
            # reset existing expiration
            Resque.redis.expire(key, ttl)
          end
        else
          # set new expiration
          if expire = unique_redis_expiration
            Resque.redis.expire(key, expire)
          end
          super
        end
      end

      def before_perform_unique_job(*args)
        Resque.redis.del(unique_redis_key(args))
      end

      def unique_key(args)
        Digest::MD5.hexdigest(encode(:class => self.to_s, :args => args))
      end

      def destroy_matching_keys(queue, args)
        queue = "queue:#{queue}"

        klass = self.to_s
        if args.empty?
          redis.lrange(queue, 0, -1).each do |string|
            if decode(string)['class'] == klass
              key = unique_redis_key(decode(string)['args'])
              Resque.redis.del(key)
            end
          end
        else
          Resque.redis.del(unique_redis_key(args))
        end
      end

      private

      def unique_redis_expiration
        600
      end

      def unique_redis_key(args)
        job_unique_key = unique_key(args)
        "plugin:unique_job:#{job_unique_key}"
      end
      # def self.extended(mod)
      #   mod.extend(Resque::Plugins::Meta)
      #   mod.extend(Resque::Plugins::Lock)
      # end
      #
      # class Step
      #   def initialize(args, run_last = false, &block)
      #     @run_last = run_last
      #     @signature = args.map{|a| a.to_s}.join(" ")
      #     if args.size == 1
      #       #no inputs or output
      #       @inputs = []
      #     elsif args.size >= 2
      #       unless @run_last
      #         @output = args.pop.to_s
      #       end
      #       @inputs = []
      #       args.each_with_index do |a, index|
      #         if index % 2 == 1
      #           @inputs << a.to_s
      #         end
      #       end
      #     else
      #       raise ArgumentError, "invalid arguments #{args.inspect}"
      #     end
      #     @block = block
      #   end
      #   attr_reader :block, :signature, :inputs, :output, :run_last
      #   # attr_accessor :run_last
      #   # attr_reader :step_name, :what_it_makes, :block
      #   def run(available_inputs)
      #     begin
      #       block_args = @inputs.map do |input_name|
      #         available_inputs[input_name]
      #       end
      #       @block.call(*block_args)
      #     rescue Exception => e
      #       puts e.inspect
      #       puts e.backtrace.join("\n")
      #       raise e
      #     end
      #   end
      # end
      #
      # #TODO:
      # #
      # # Need a way to edit meta data BEFORE a job is enQ'd
      # # so that we can we sure that data is available on dQ
      # #
      # # Need a way to "Lock" editing of the meta data on a job
      # # so other editors of job data must wait before editing job
      # # (2 jobs marking a step done and then, therefore re-enQ-ing the parent)
      # #
      # # need a way to mark a job as already enQ'd (and not yet running)
      # # so that if the tomato just re-enQ'd the sandwich, the cheese will see it on the Q and let it be
      # #
      # # basically, there should be a lock such that if there are any child jobs still enQ'd for a job
      # # it should not run but prioritize the child jobs first
      #
      # class StepDependency
      #   def initialize(job_class, args)
      #     @job_class = job_class
      #     @job_args = args
      #   end
      #   attr_reader :job_class, :job_args
      # end
      #
      # class Retry
      #   def initialize(seconds)
      #     @seconds = seconds
      #   end
      #   attr_reader :seconds
      # end
      #
      # def run_steps(meta_id, *args)
      #   @step_list = []
      #   @meta = self.get_jobdata(meta_id)
      #   # puts "I have meta of: " + @meta.inspect
      #
      #   #implicitly builds the @step_list
      #   steps(*args)
      #
      #   #TODO: raise error if there are duplicate steps defined?
      #
      #   # require 'pp'
      #   # pp @step_list
      #
      #   #figure out which step we are on from meta data
      #   @meta["step_count"] ||= @step_list.size
      #   steps_ran = @meta["steps_ran"] ||= []
      #   steps_running = @meta["steps_running"] ||= []
      #   # puts "my steps_ran are #{steps_ran.inspect}"
      #   # @step_list.map{ |step| step.signature }
      #   available_inputs = @meta["available_inputs"] ||= {}
      #   # puts "my available_inputs are #{available_inputs.inspect}"
      #
      #   #run last step if no more steps are needed
      #   @step_list.each do |step|
      #     if steps_ran.include?(step.signature)
      #       #already ran
      #     elsif steps_running.include?(step.signature)
      #       #already Q'd
      #     elsif step.run_last
      #       # puts "Can't run last step #{step.signature} yet"
      #       #this is the last step, only run if all other steps are run
      #     elsif (step.inputs - available_inputs.keys).empty?
      #       #all of the steps needed inputs are available
      #       #run!
      #       result = step.run(available_inputs)
      #       puts "running step #{step.signature}"
      #       if result.is_a?(Retry)
      #         puts "enqueue #{self} in #{result.seconds}"
      #         Resque.enqueue_in(result.seconds, self, meta_id, *args)
      #       elsif result.is_a?(StepDependency)
      #         #TODO: what if the child job is dQ'd before caller has a chance to set parent_job
      #         # don't re-enQ a child that's already enQ'd!
      #         # it might not be in steps ran but it doesn't need to be duplicated!
      #         puts "enqueue #{result.job_class}"
      #         child_job = result.job_class.enqueue(*result.job_args)
      #         @meta["steps_running"] << step.signature
      #         child_job["parent_job"] = [self, meta_id, args]
      #         child_job["expected_output"] = step.output
      #         child_job["signature_from_parent"] = step.signature
      #         child_job.save
      #       else
      #         if step.output
      #           available_inputs[step.output] = result
      #         end
      #         # puts "available_inputs are now #{available_inputs.inspect}"
      #         if @meta["steps_ran"].include?(step.signature)
      #           raise "WHAT? ran #{step.signature} twice!"
      #         end
      #         @meta["steps_ran"] << step.signature
      #       end
      #     else
      #       # puts "waiting before we can run step #{step.signature} -- need #{step.inputs}"
      #     end
      #   end
      #
      #   if steps_ran.size + 1 == @step_list.size
      #     puts "now running last step of #{self} -- already ran #{steps_ran.inspect}"
      #
      #     step = @step_list.last
      #     result = step.run(available_inputs)
      #     if @meta["parent_job"]
      #       # puts "#{meta_id} has parent"
      #       parent_job_class_name, parent_meta_id, parent_args = @meta["parent_job"]
      #       parent_job_class = const_get(parent_job_class_name)
      #       parent_meta = parent_job_class.get_jobdata(parent_meta_id)
      #       if expected_output = @meta["expected_output"]
      #         parent_meta["available_inputs"][expected_output] = result
      #         parent_meta.save
      #       end
      #       if @meta["signature_from_parent"]
      #         if parent_meta["steps_ran"].include?(@meta["signature_from_parent"])
      #           raise "WHAT? ran #{@meta["signature_from_parent"]} twice!"
      #         end
      #         parent_meta["steps_ran"] << @meta["signature_from_parent"]
      #         parent_meta.save
      #       end
      #       puts "enqueue #{parent_job_class}"
      #       Resque.enqueue(parent_job_class, parent_meta_id, *parent_args)
      #     end
      #     if @meta["steps_ran"].include?(step.signature)
      #       raise "WHAT? ran #{step.signature} twice!"
      #     end
      #     @meta["steps_ran"] << step.signature
      #   end
      #   @meta.save
      #
      #   puts "End of #{self}"
      # end
      #
      # def step(*args, &block)
      #   @step_list << Step.new(args, &block)
      # end
      #
      # def last_step(*args, &block)
      #   @step_list << Step.new(args, true, &block)
      # end
      #
      # def depend_on(job_class, *args)
      #   StepDependency.new(job_class, args)
      # end
      #
      # def retry_in(seconds)
      #   Retry.new(seconds)
      # end
      #
      # def get_jobdata(meta_id)
      #   get_meta(meta_id)
      # end

    end
  end
end