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
      def start_cron_scheduler!(cron, opts = {}, &task)
        unless block_given?
          raise ArgumentError, 'missing task - worker task to execute'
        end
        scheduler = new_scheduler(opts)
        scheduler.schedule_cron(cron, &task)
        scheduler
      end

      %w(every at in interval).each do |type|
        class_eval <<-EVAL, __FILE__, __LINE__ + 1
          def start_#{type}_scheduler!(arg, opts = {}, &task)
            unless block_given?
              raise ArgumentError, 'missing task - worker task to execute'
            end
            scheduler = new_scheduler(opts)
            scheduler.schedule_#{type}(arg, &task)
            scheduler
          end
        EVAL
      end

      # @param opts [Hash] scheduler options
      # @return scheduler instance
      def new_scheduler(opts)
        unless opts.key?(:thread_name)
          unless self.class.name
            raise ArgumentError, "can not generate a thread_name for anonymous class: #{inspect}"
          end
          pipeline_id = (respond_to?(:execution_context) && execution_context&.pipeline_id) || 'main'
          plugin_name = self.class.name.split('::').last # e.g. "jdbc"
          opts[:thread_name] = "[#{pipeline_id}]|#{self.class.plugin_type}|#{plugin_name}|scheduler"
          # thread naming convention: [psql1]|input|jdbc|scheduler
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
