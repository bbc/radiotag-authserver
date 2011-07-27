require 'rake'
require 'rake/testtask'

task :default => [:test]

desc "Run tests"
Rake::TestTask.new("test") { |t|
  t.pattern = FileList['test/authserver_test.rb']
}
