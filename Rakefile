# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts 'Run `bundle install` to install missing gems'
  exit e.status_code
end
require 'rake'

require 'jeweler'
require 'lib/twi_meido/version'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = 'TwiMeido'
  gem.homepage = 'http://code.google.com/p/twi-meido'
  gem.license = 'GPL-2'
  gem.summary = %Q{TwiMeido is a Twitter client using Streaming API for XMPP clients, e.g. Google Talk.}
  gem.description = %Q{TwiMeido is a Twitter client for XMPP clients, e.g. Google Talk. TwiMeido use Twitter Streaming API to monitor and notify the tweets you're interested nearly real-time.}
  gem.email = 'rainux@gmail.com'
  gem.authors = ['Rainux Luo']
  gem.version = TwiMeido::Version
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :default => :spec

require 'yard'
YARD::Rake::YardocTask.new
