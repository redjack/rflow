require 'bundler'
require 'rspec/core/rake_task'
require 'rdoc/task'
Bundler::GemHelper.install_tasks

RSpec::Core::RakeTask.new(:spec) do |t|
  t.verbose = true
  t.rspec_opts = '--tty --color'
end

RDoc::Task.new do |rd|
  rd.main = "README"
  rd.rdoc_files.include("README", "lib/**/*.rb")
  rd.rdoc_dir = File.join('doc', 'html')
end

