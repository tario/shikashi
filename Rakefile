require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
  s.name = 'caja'
  s.version = '0.0.0'
  s.author = 'Dario Seminara'
  s.email = 'robertodarioseminara@gmail.com'
  s.platform = Gem::Platform::RUBY
  s.summary = 'caja is a ruby sandbox that permits the execution of "unprivileged" scripts by defining the permitted methods and constants the scripts can invoke (I.E., the script cannot use the File class or a RoR Model Class unless that permission is specified) "well done version" of ruby-arena-sanbox based on rallhook'
  s.homepage = "http://github.com/tario/caja"
  s.add_dependency "rallhook", ">= 0.5.0"  
  s.has_rdoc = true
  s.extra_rdoc_files = [ 'README' ]
#  s.rdoc_options << '--main' << 'README'
  s.files = Dir.glob("{examples,lib,test}/**/*") +
    [ 'AUTHORS', 'CHANGELOG', 'README', 'Rakefile', 'TODO' ]
end

desc 'Run tests'
task :default => [ :test ]

Rake::TestTask.new('test') do |t|
  t.libs << 'test'
  t.pattern = '{test}/test_*.rb'
  t.verbose = true
end

desc 'Generate RDoc'
Rake::RDocTask.new :rdoc do |rd|
  rd.rdoc_dir = 'doc'
  rd.rdoc_files.add 'lib', 'README'
  rd.main = 'README'
end

desc 'Build Gem'
Rake::GemPackageTask.new spec do |pkg|
  pkg.need_tar = true
end

desc 'Clean up'
task :clean => [ :clobber_rdoc, :clobber_package ]

desc 'Clean up'
task :clobber => [ :clean ]
