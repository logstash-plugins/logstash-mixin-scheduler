# Scheduler Mixin

[![Unit Tests](https://github.com/logstash-plugins/logstash-mixin-scheduler/actions/workflows/unit-tests.yml/badge.svg?branch=main)](https://github.com/logstash-plugins/logstash-mixin-scheduler/actions/workflows/unit-tests.yml)


## Usage

1. Add this gem as a runtime dependency of your Logstash plugin's `gemspec`:

    ~~~ ruby
    Gem::Specification.new do |s|
      # ...

      s.add_runtime_dependency 'logstash-mixin-scheduler', '~> 1.0'
    end
    ~~~

2. In your plugin code, require this library and include it into your plugin class
   that already inherits `LogStash::Plugin`:

    ~~~ ruby
    require 'logstash/plugin_mixins/scheduler'

    class LogStash::Inputs::Bar < Logstash::Inputs::Base

      include LogStash::PluginMixins::Scheduler
   
      # Schedule of when to periodically run statement, in Cron format
      # for example: "* * * * *" (execute query every minute, on the minute)
      config :schedule, :validate => :string
   
      def run(queue)
        if @schedule
          scheduler.cron(@schedule) { serve_drinks(queue) }
          scheduler.join
        else
          serve_drinks(queue)
        end
      end
   
      # def server_drinks ...
   
    end
    ~~~

## Development

This gem:
 - *MUST* remain API-stable at 1.x
 - *MUST NOT* introduce additional runtime dependencies
