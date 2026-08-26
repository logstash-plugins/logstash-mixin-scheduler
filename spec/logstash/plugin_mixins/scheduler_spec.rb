# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/plugin_mixins/scheduler"

module LogStash
  module Inputs
    class Foo < LogStash::Inputs::Base
      include LogStash::PluginMixins::Scheduler
      config_name 'foo'
    end
  end
end

module LogStash
  module Filters
    class Bar < LogStash::Inputs::Base
      include LogStash::PluginMixins::Scheduler
      config_name 'bar'
    end
  end
end

describe LogStash::PluginMixins::Scheduler do

  subject(:mixin) { described_class }

  context 'included into a class' do
    context 'that does not inherit from `LogStash::Plugin`' do
      let(:plugin_class) { Class.new }
      it 'fails with an ArgumentError' do
        expect do
          plugin_class.send(:include, mixin)
        end.to raise_error(ArgumentError, /LogStash::Plugin/)
      end
    end

    [ LogStash::Inputs::Foo, LogStash::Filters::Bar ].each do |base_class|
      context "#{base_class} plugin" do

        let(:plugin_class) { base_class }

        it 'works when mixin is includes and provides a scheduler method' do
          plugin = plugin_class.new Hash.new
          expect( plugin.scheduler ).to be_a LogStash::PluginMixins::Scheduler::SchedulerInterface
        end

        context 'hooks' do

          let(:plugin) { plugin_class.new Hash.new }

          it 'shuts-down the scheduler on close' do
            scheduler = plugin.scheduler
            expect( scheduler.running? ).to be true
            plugin.do_close
            expect( scheduler.running? ).to be false
          end

          it 'terminates scheduler work threads on close' do
            scheduler = plugin.scheduler
            ran = java.util.concurrent.CountDownLatch.new(1)
            scheduler.every('1s') { ran.count_down }
            expect( ran.await(10, java.util.concurrent.TimeUnit::SECONDS) ).to be true
            work_threads = scheduler.impl.work_threads
            expect( work_threads.count(&:alive?) ).to be >= 1
            plugin.do_close
            try(10) { expect( work_threads.count(&:alive?) ).to eql 0 }
          end

          it 'shuts-down the scheduler on stop' do
            scheduler = plugin.scheduler
            plugin.stop
            expect( scheduler.running? ).to be false
          end

        end
      end
    end
  end
end