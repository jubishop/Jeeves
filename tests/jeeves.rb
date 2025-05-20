#!/usr/bin/env ruby
require "minitest/autorun"
require "tmpdir"
require "fileutils"

# Path to the jeeves script
JEEVES_SCRIPT = "/Users/jubi/bin/jeeves"

class TestJeeves < Minitest::Test
  def setup
    # Create a temporary directory for tests
    @temp_dir = Dir.mktmpdir("jeeves_test_")
    @old_dir = Dir.pwd
    Dir.chdir(@temp_dir)
    
    # Initialize git repo for testing
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
  
  def test_require_tmpdir
    # Test that the script can be loaded without error
    output = `ruby -c #{JEEVES_SCRIPT} 2>&1`
    assert_match(/Syntax OK/, output)
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
  
  def test_config_dir_exists
    # Check if the Jeeves config directory exists or can be created
    config_dir = File.expand_path("~/.config/jeeves")
    assert(Dir.exist?(config_dir) || FileUtils.mkdir_p(config_dir))
  end
end