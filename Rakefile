# frozen_string_literal: true

require_relative 'lib/jeeves/runtime'
Jeeves::Runtime.check!
require 'rake/testtask'
require 'fileutils'
require_relative 'lib/jeeves/version'

Rake::TestTask.new(:test) do |task|
  task.libs << 'test' << 'lib'
  task.test_files = FileList['test/jeeves/*_test.rb']
end

desc 'Lint the application and tests'
task :lint do
  files = FileList['lib/*.rb', 'lib/jeeves/*.rb', 'test/*.rb', 'test/jeeves/*_test.rb']
  ruby '-S', 'rubocop', '--lint', '--cache', 'false', *files, 'bin/jeeves', 'Rakefile', 'jeeves.gemspec'
end

desc 'Build the gem in gems/'
task :build do
  FileUtils.mkdir_p('gems')
  sh 'gem', 'build', 'jeeves.gemspec', '--output', "gems/jeeves-git-commit-#{Jeeves::VERSION}.gem"
end

desc 'Run application tests, lint, and package validation'
task validate: %i[test lint build]

desc 'Build, test, and install the gem'
task install: %i[test build] do
  sh 'gem', 'install', "gems/jeeves-git-commit-#{Jeeves::VERSION}.gem"
end

desc 'Validate and publish to RubyGems (explicit release action)'
task push: :validate do
  sh 'gem', 'push', "gems/jeeves-git-commit-#{Jeeves::VERSION}.gem"
end

task default: :test
