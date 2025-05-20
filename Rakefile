require 'rake/testtask'
require 'fileutils'
require_relative 'lib/jeeves/version'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

desc 'Build the gem and place it in the gemspec/ folder'
task :build do
  # Build the gem
  sh "gem build gemspec/jeeves.gemspec"
  
  # Get the version
  version = Jeeves::VERSION
  
  # Move the gem file to the gemspec/ folder
  gem_file = "jeeves-git-commit-#{version}.gem"
  if File.exist?(gem_file)
    FileUtils.mv(gem_file, "gemspec/#{gem_file}")
    puts "Successfully built and moved #{gem_file} to gemspec/ folder"
  else
    puts "Error: Could not find #{gem_file}"
  end
end

desc 'Build, install and test the gem'
task install: :build do
  version = Jeeves::VERSION
  gem_file = "gemspec/jeeves-git-commit-#{version}.gem"
  sh "gem install #{gem_file}"
end

task default: :test
