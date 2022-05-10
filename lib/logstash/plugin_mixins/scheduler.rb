# encoding: utf-8

require 'logstash/namespace'
require 'logstash/plugin'

require 'logstash/plugin_mixins/scheduler/rufus_impl'

module LogStash
  module PluginMixins
    module Scheduler

      # @param cron [String] cron-line
      # @param opts [Hash] scheduler options
      # @return scheduler instance
      def start_cron_scheduler(cron, opts = {}, &block)
        unless block_given?
          raise ArgumentError, 'missing (cron scheduler) block - worker task to execute'
        end
        scheduler = new_scheduler(opts)
        scheduler.schedule_cron(cron, &block)
        scheduler
      end

      # @param opts [Hash] scheduler options
      # @return scheduler instance
      def new_scheduler(opts)
        unless opts.key?(:thread_name)
          raise ArgumentError, 'thread_name: option is required to be able to distinguish multiple scheduler threads'
        end
        opts[:max_work_threads] ||= 1
        # amount the scheduler thread sleeps between checking whether jobs
        # should trigger, default is 0.3 which is a bit too often ...
        # in theory the cron expression '* * * * * *' supports running jobs
        # every second but this is very rare, we could potentially go higher
        opts[:frequency] ||= 1.0

        RufusImpl.new(opts)
      end

    end
  end
end