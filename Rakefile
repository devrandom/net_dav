require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "net_dav"
    gem.summary = %Q{WebDAV client library in the style of Net::HTTP}
    gem.description = %Q{WebDAV client library in the style of Net::HTTP, using Net::HTTP and libcurl, if installed}
    gem.email = "c1.github@niftybox.net"
    gem.homepage = "http://github.com/devrandom/net_dav"
    gem.authors = ["Miron Cuperman","Thomas Flemming"]
    gem.executables = ["dav"]
    gem.add_dependency "nokogiri", ">= 1.3.0"
    gem.add_development_dependency "rspec", ">= 1.2.0"
    gem.add_development_dependency "webrick-webdav", ">= 1.0"

    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rspec_opts = %w(-fs --color)
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :default => :spec

desc "release with no version change"
task :dist => [:clean, :release]

namespace :dist do
  desc "release patch"
  task :patch => [:clean, "version:bump:patch", :release]
  desc "release with minor version bump"
  task :minor => [:clean, "version:bump:minor", :release]
end

desc "build gem into pkg directory"
task :gem => [:build]

task :clean do
  Dir.glob("**/*~").each do |file|
    File.unlink file
  end
  puts "cleaned"
end

require 'rdoc/task'

Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "net_dav #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
