require 'rubygems'
require 'rake'
require 'rdoc/task'
require 'rubygems/package_task'
require 'rake/testtask'

spec = Gem::Specification.new do |s|
  s.name = 'shikashi'
  s.version = '0.6.0'
  s.author = 'Dario Seminara'
  s.email = 'robertodarioseminara@gmail.com'
  s.platform = Gem::Platform::RUBY
  s.summary = 'shikashi is a ruby sandbox that permits the execution of "unprivileged" scripts by defining the permitted methods and constants the scripts can invoke with a white list logic'
  s.homepage = "http://github.com/tario/shikashi"
  s.add_dependency "evalhook", ">= 0.6.0"
  s.add_dependency "getsource", ">= 0.1.0"
  s.has_rdoc = true
  s.extra_rdoc_files = [ 'README' ]
#  s.rdoc_options << '--main' << 'README'
  s.files = Dir.glob("{examples,lib,test}/**/*") +
    [ 'LICENSE', 'AUTHORS', 'CHANGELOG', 'README', 'Rakefile', 'TODO' ]
end

desc 'Generate RDoc'
Rake::RDocTask.new :rdoc do |rd|
  rd.rdoc_dir = 'doc'
  rd.rdoc_files.add 'lib', 'README'
  rd.main = 'README'
end

desc 'Build Gem'
Gem::PackageTask.new spec do |pkg|
  pkg.need_tar = true
end

desc 'Clean up'
task :clean => [ :clobber_rdoc, :clobber_package ]

desc 'Clean up'
task :clobber => [ :clean ]
