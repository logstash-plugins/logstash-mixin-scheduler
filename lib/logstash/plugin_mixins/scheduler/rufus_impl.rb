require 'rufus/scheduler'

require 'logstash/util/loggable'

module LogStash module PluginMixins module Scheduler
  class RufusImpl < Rufus::Scheduler

    include LogStash::Util::Loggable

    # Rufus::Scheduler >= 3.4 moved the Time impl into a gem EoTime = ::EtOrbi::EoTime`
    # Rufus::Scheduler 3.1 - 3.3 using it's own Time impl `Rufus::Scheduler::ZoTime`
    TimeImpl = defined?(Rufus::Scheduler::EoTime) ? Rufus::Scheduler::EoTime :
                   (defined?(Rufus::Scheduler::ZoTime) ? Rufus::Scheduler::ZoTime : ::Time)

    # @overload
    def join
      fail NotRunningError.new('cannot join scheduler that is not running') unless @thread
      fail ThreadError.new('scheduler thread cannot join itself') if @thread == Thread.current
      @thread.join # makes scheduler.join behavior consistent across 3.x versions
    end

    # @overload
    def shutdown(opt=nil)
      if @thread # do not fail when scheduler thread failed to start
        super(opt)
      else
        @started_at = nil # bare minimum to look like the scheduler is down
        # when the scheduler thread fails `@started_at = ...` might still be set
      end
    end

    # @overload
    def timeout_jobs
      # Rufus relies on `Thread.list` which is a blocking operation and with many schedulers
      # (and threads) within LS will have a negative impact on performance as scheduler
      # threads will end up waiting to obtain the `Thread.list` lock.
      #
      # However, this isn't necessary we can easily detect whether there are any jobs
      # that might need to timeout: only when `@opts[:timeout]` is set causes worker thread(s)
      # to have a `Thread.current[:rufus_scheduler_timeout]` that is not nil
      return unless @opts[:timeout]
      super
    end

    # @overload
    def work_threads(query = :all)
      if query == :__all_no_cache__ # special case from JobDecorator#start_work_thread
        @_work_threads = nil # when a new worker thread is being added reset
        return super(:all)
      end

      # Gets executed every time a job is triggered, we're going to cache the
      # worker threads for this scheduler (to avoid `Thread.list`) - they only
      # change when a new thread is being started from #start_work_thread ...
      work_threads = @_work_threads
      if work_threads.nil?
        work_threads = threads.select { |t| t[:rufus_scheduler_work_thread] }
        @_work_threads = work_threads
      end

      case query
      when :active then work_threads.select { |t| t[:rufus_scheduler_job] }
      when :vacant then work_threads.reject { |t| t[:rufus_scheduler_job] }
      else work_threads
      end
    end

    # @overload
    def on_error(job, err)
      details = { exception: err.class, message: err.message, backtrace: err.backtrace }
      details[:cause] = err.cause if err.cause

      details[:now] = debug_format_time(TimeImpl.now)
      details[:last_time] = (debug_format_time(job.last_time) rescue nil)
      details[:next_time] = (debug_format_time(job.next_time) rescue nil)
      details[:job] = job

      details[:opts] = @opts
      details[:started_at] = started_at
      details[:thread] = thread.inspect
      details[:jobs_size] = @jobs.size
      details[:work_threads_size] = work_threads.size
      details[:work_queue_size] = work_queue.size

      logger.error("Scheduler intercepted an error:", details)

    rescue => e
      logger.error("Scheduler failed in #on_error #{e.inspect}")
    end

    def debug_format_time(time)
      # EtOrbi::EoTime used by (newer) Rufus::Scheduler has to_debug_s https://git.io/JyiPj
      time.respond_to?(:to_debug_s) ? time.to_debug_s : time.strftime("%Y-%m-%dT%H:%M:%S.%L")
    end
    private :debug_format_time

    # @private helper used by JobDecorator
    def work_thread_name_prefix
      ( @opts[:thread_name] || "#{@thread_key}_scheduler" ) + '_worker-'
    end

    protected

    # @overload
    def start
      ret = super() # @thread[:name] = @opts[:thread_name] || "#{@thread_key}_scheduler"

      # at least set thread.name for easier thread dump analysis
      if @thread.is_a?(Thread) && @thread.respond_to?(:name=)
        @thread.name = @thread[:name] if @thread[:name]
      end

      ret
    end

    # @overload
    def do_schedule(job_type, t, callable, opts, return_job_instance, block)
      job_or_id = super

      job_or_id.extend JobDecorator if return_job_instance

      job_or_id
    end

    module JobDecorator

      def start_work_thread
        prev_thread_count = @scheduler.work_threads.size

        ret = super() # does not return Thread instance in 3.0

        work_threads = @scheduler.work_threads(:__all_no_cache__)
        while prev_thread_count == work_threads.size # very unlikely
          Thread.pass
          work_threads = @scheduler.work_threads(:__all_no_cache__)
        end

        work_thread_name_prefix = @scheduler.work_thread_name_prefix

        work_threads.sort! do |t1, t2|
          if t1[:name].nil?
            t2[:name].nil? ? 0 : +1 # nils at the end
          elsif t2[:name].nil?
            t1[:name].nil? ? 0 : -1
          else
            t1[:name] <=> t2[:name]
          end
        end

        work_threads.each_with_index do |thread, i|
          unless thread[:name]
            thread[:name] = "#{work_thread_name_prefix}#{sprintf('%02i', i)}"
            thread.name = thread[:name] if thread.respond_to?(:name=)
            # e.g. "[oracle]<jdbc_scheduler_worker-00"
          end
        end

        ret
      end

    end

  end
end end end