Gem::Specification.new do |s|
  s.name          = 'logstash-mixin-scheduler'
  s.version       = '1.0.1'
  s.licenses      = %w(Apache-2.0)
  s.summary       = "Scheduler for Logstash plugins"
  s.authors       = %w(Elastic)
  s.email         = 'info@elastic.co'
  s.homepage      = 'https://github.com/logstash-plugins/logstash-mixin-scheduler'
  s.require_paths = %w(lib)

  s.files = %w(lib spec vendor).flat_map{|dir| Dir.glob("#{dir}/**/*")}+Dir.glob(["*.md","LICENSE"])

  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  s.platform = 'java'

  s.add_runtime_dependency 'logstash-core', '>= 7.16'

  # In future releases we may remove this dependency,
  # but we cannot tighten constraints without introducing
  # dependency conflicts with plugins that rely on rufus directly.
  s.add_runtime_dependency 'rufus-scheduler', '>= 3.0.9'

  s.add_development_dependency 'logstash-devutils'
  s.add_development_dependency 'logstash-codec-plain'
  s.add_development_dependency 'rspec', '~> 3.9'
end
