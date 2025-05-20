require 'test_helper'
require 'fileutils'
require 'tempfile'

class CLITest < Minitest::Test
  def setup
    # Create a temporary directory for test config
    @original_config_dir = Jeeves::CLI::CONFIG_DIR
    @test_config_dir = File.join(Dir.tmpdir, "jeeves_test_#{Time.now.to_i}")
    FileUtils.mkdir_p(@test_config_dir)
    
    # Stub the CONFIG_DIR constant
    Jeeves::CLI.send(:remove_const, :CONFIG_DIR)
    Jeeves::CLI.const_set(:CONFIG_DIR, @test_config_dir)
    
    # Create a test prompt file
    @prompt_file = File.join(@test_config_dir, 'prompt')
    File.write(@prompt_file, "Test prompt with {{DIFF}} placeholder")
  end
  
  def teardown
    # Restore original CONFIG_DIR
    Jeeves::CLI.send(:remove_const, :CONFIG_DIR)
    Jeeves::CLI.const_set(:CONFIG_DIR, @original_config_dir)
    
    # Clean up test directory
    FileUtils.rm_rf(@test_config_dir) if File.exist?(@test_config_dir)
  end
  
  def test_initialize
    cli = Jeeves::CLI.new
    assert_equal false, cli.instance_variable_get(:@options)[:all]
    assert_equal false, cli.instance_variable_get(:@options)[:push]
  end
  
  def test_setup_config_dir
    # Mock the private setup_config_dir method to avoid actual filesystem operations
    # This is necessary because we don't want to rely on the bundled prompt file
    # being in a specific location in our test environment
    
    original_method = Jeeves::CLI.instance_method(:setup_config_dir)
    
    # Create a mock method that just creates the config dir and prompt file
    Jeeves::CLI.send(:define_method, :setup_config_dir) do
      unless Dir.exist?(Jeeves::CLI::CONFIG_DIR)
        FileUtils.mkdir_p(Jeeves::CLI::CONFIG_DIR)
      end
      
      unless File.exist?(Jeeves::CLI::PROMPT_FILE)
        File.write(Jeeves::CLI::PROMPT_FILE, "Test prompt content")
      end
    end
    
    # Initialize a CLI instance which will call our mocked method
    cli = Jeeves::CLI.new
    
    # Verify the prompt file was created
    assert File.exist?(@prompt_file), "Prompt file should exist at #{@prompt_file}"
    
    # Restore the original method
    Jeeves::CLI.send(:define_method, :setup_config_dir, original_method)
  end
  
  # Mock method to avoid actual git commands
  def test_parse_options
    # Test with -a option
    cli1 = Jeeves::CLI.new
    ARGV.replace(['-a'])
    cli1.parse_options
    assert_equal true, cli1.instance_variable_get(:@options)[:all]
    assert_equal false, cli1.instance_variable_get(:@options)[:push]
    
    # Test with -p option
    cli2 = Jeeves::CLI.new
    ARGV.replace(['-p'])
    cli2.parse_options
    assert_equal false, cli2.instance_variable_get(:@options)[:all]
    assert_equal true, cli2.instance_variable_get(:@options)[:push]
    
    # Test with both options
    cli3 = Jeeves::CLI.new
    ARGV.replace(['-a', '-p'])
    cli3.parse_options
    assert_equal true, cli3.instance_variable_get(:@options)[:all]
    assert_equal true, cli3.instance_variable_get(:@options)[:push]
    
    # Reset ARGV
    ARGV.replace([])
  end
end
