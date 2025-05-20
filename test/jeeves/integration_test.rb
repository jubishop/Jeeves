require 'test_helper'
require 'tmpdir'
require 'fileutils'

class IntegrationTest < Minitest::Test
  def setup
    # Create a temporary directory for tests
    @temp_dir = Dir.mktmpdir("jeeves_test_")
    @old_dir = Dir.pwd
    Dir.chdir(@temp_dir)
    
    # Initialize git repo for testing
    # Using system to handle the output, checking the status for fish shell compatibility
    system("git init > /dev/null")
    system("git config user.name \"Test User\"")
    system("git config user.email \"test@example.com\"")
    
    # Create a test file
    File.write("test_file.txt", "Test content")
    system("git add test_file.txt")
  end
  
  def teardown
    # Clean up
    Dir.chdir(@old_dir)
    FileUtils.remove_entry(@temp_dir)
  end
  
  def test_config_dir_exists
    # Check if the Jeeves config directory exists or can be created
    config_dir = File.expand_path("~/.config/jeeves")
    assert(Dir.exist?(config_dir) || FileUtils.mkdir_p(config_dir))
  end
  
  def test_tmpdir_functionality
    # Test that Dir.tmpdir actually works
    temp_file_path = File.join(Dir.tmpdir, "jeeves_tmpdir_test")
    
    # Try to create a temporary file
    File.write(temp_file_path, "test")
    assert File.exist?(temp_file_path), "Should be able to create a file in Dir.tmpdir"
    
    # Clean up
    File.unlink(temp_file_path) if File.exist?(temp_file_path)
  end
  
  def test_executable
    # Find the executable path dynamically
    executable_path = nil
    if ENV['BUNDLE_GEMFILE']
      # If running through bundle exec, find gem's bin
      executable_path = File.expand_path('../../bin/jeeves', __dir__)
    else
      # Try to find in PATH
      path = `which jeeves`.strip
      executable_path = path unless path.empty?
      
      # Fallback to gem's bin
      executable_path ||= File.expand_path('../../bin/jeeves', __dir__)
    end
    
    # Ensure it exists
    assert File.exist?(executable_path), "Executable not found at #{executable_path}"
    
    # Test syntax
    output = `ruby -c #{executable_path} 2>&1`
    assert_match(/Syntax OK/, output)
  end
end
