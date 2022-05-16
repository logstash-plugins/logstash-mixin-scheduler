# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/plugin_mixins/scheduler"

describe LogStash::PluginMixins::Scheduler::RufusImpl do

  let(:name) { '[test]<jdbc_scheduler' }

  let(:opts) do
    { :max_work_threads => 2 }
  end

  subject(:scheduler) do
    LogStash::PluginMixins::Scheduler::RufusImpl::SchedulerAdapter.new(name, opts)
  end

  after { scheduler.impl.shutdown }

  it "sets scheduler thread name" do
    expect( scheduler.impl.thread.name ).to include name
  end

  it "gets interrupted from join" do
    scheduler.every('1s') { 42**1000 }
    join_thread = Thread.start { scheduler.join }
    sleep 1.1
    expect(join_thread).to be_alive
    expect(scheduler.shutdown?).to be false
    scheduler.shutdown
    Thread.pass
    expect(scheduler.shutdown?).to be true
    expect(join_thread).to_not be_alive
  end

  it "gets interrupted from join (wait shutdown)" do
    scheduler.cron('* * * * * *') { 42**1000 }
    expect(scheduler.shutdown?).to be false
    join_thread = Thread.start { scheduler.join }
    sleep 1.1
    expect(join_thread).to be_alive
    scheduler.shutdown!
    expect(scheduler.shutdown?).to be true
    expect(join_thread).to_not be_alive
  end

  context 'cron schedule' do

    before do
      scheduler.cron('* * * * * *') { sleep 1.25 } # every second
    end

    it "sets worker thread names" do
      sleep 3.0
      threads = scheduler.impl.work_threads
      threads.sort! { |t1, t2| (t1.name || '') <=> (t2.name || '') }

      expect( threads.size ).to eql 2
      expect( threads.first.name ).to eql "#{name}_worker-00"
      expect( threads.last.name ).to eql "#{name}_worker-01"
    end

  end

  context 'every 1s' do

    before do
      scheduler.in('1s') { raise 'TEST' } # every second
    end

    it "logs errors handled" do
      expect( scheduler.impl.send(:logger) ).to receive(:error).with /Scheduler intercepted an error/, hash_including(:message => 'TEST')
      sleep 2.25
    end

  end

  context 'work threads' do

    let(:opts) { super().merge :max_work_threads => 3 }

    let(:counter) { java.util.concurrent.atomic.AtomicLong.new(0) }

    before do
      scheduler.cron('* * * * * *') { counter.increment_and_get; sleep 3.25 } # every second
    end

    it "are working" do
      sleep(0.05) while counter.get == 0
      expect( scheduler.impl.work_threads.size ).to eql 1
      sleep(0.05) while counter.get == 1
      expect( scheduler.impl.work_threads.size ).to eql 2
      sleep(0.05) while counter.get == 2
      expect( scheduler.impl.work_threads.size ).to eql 3

      sleep 1.25
      expect( scheduler.impl.work_threads.size ).to eql 3
      sleep 1.25
      expect( scheduler.impl.work_threads.size ).to eql 3
    end

  end

end