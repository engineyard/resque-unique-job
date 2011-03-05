require 'lib/resque/plugins/unique_job/version'

Gem::Specification.new do |s|
  s.name              = 'resque-unique-job'
  s.version           = Resque::Plugins::UniqueJob::Version
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = 'A Resque plugin for unique jobs'
  s.homepage          = 'http://github.com/engineyard/resque-unique-job'
  s.email             = 'cloud@engineyard.com'
  s.authors           = [ 'Andy Delcambre', 'Jacob Burkhart' ]
  s.has_rdoc          = false

  s.files             = %w( README.markdown Rakefile LICENSE )
  s.files            += Dir.glob('lib/**/*')
  s.files            += Dir.glob('spec/**/*')

  s.add_dependency 'resque', '>= 1.8.0'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'ruby-debug'

  s.description       = "A Resque plugin for unique jobs"

end