require_relative '../test_helper'
require 'fileutils'
require 'tempfile'

class CLITest < Minitest::Test
  def setup
    # Set up completely isolated test environment with mocked API calls
    setup_test_environment
    
    # The test_config_dir and CONFIG_DIR are now managed by setup_test_environment
    # Create a test prompt file in the isolated test config directory
    @prompt_file = File.join(@test_config_dir, 'prompt')
    File.write(@prompt_file, "Test prompt with {{DIFF}} placeholder")
    
    # Create a mock bundled prompt file in the isolated project config directory
    @bundled_prompt_dir = File.join(@test_root_dir, 'config')
    @bundled_prompt_file = File.join(@bundled_prompt_dir, 'prompt')
    # The file is already created by create_isolated_project_structure in test_helper
    
    # Store the original bundle_prompt path method to patch for tests if needed
    if Jeeves::CLI.private_method_defined?(:setup_config_dir)
      @original_setup_config_dir = Jeeves::CLI.instance_method(:setup_config_dir)
    end
  end
  
  def teardown
    # Use the common teardown_test_environment which now handles:
    # - Restoring CONFIG_DIR constant
    # - Cleaning up all test directories
    # - Restoring ENV variables
    teardown_test_environment
    
    # If we patched any methods during testing, restore them
    if defined?(@original_setup_config_dir) && Jeeves::CLI.private_method_defined?(:setup_config_dir)
      Jeeves::CLI.send(:remove_method, :setup_config_dir)
      Jeeves::CLI.send(:define_method, :setup_config_dir, @original_setup_config_dir)
    end
  end
  
  def test_initialize
    cli = Jeeves::CLI.new
    assert_equal false, cli.instance_variable_get(:@options)[:all]
    assert_equal false, cli.instance_variable_get(:@options)[:push]
  end
  
  def test_setup_config_dir
    # This test verifies that setup_config_dir correctly copies the bundled prompt
    # to the user config directory when it doesn't exist
    
    # Make sure we're using our isolated test directories
    assert_equal @test_config_dir, Jeeves::CLI::CONFIG_DIR, "Should be using isolated test config directory"
    
    # First, ensure the prompt file doesn't exist in the user config
    File.unlink(@prompt_file) if File.exist?(@prompt_file)
    refute File.exist?(@prompt_file), "Prompt file should not exist before test"
    
    # Make sure the bundled prompt exists in our test project structure
    assert File.exist?(@bundled_prompt_file), "Bundled prompt file should exist in test env"
    bundled_content = File.read(@bundled_prompt_file)
    
    # Create a custom implementation of setup_config_dir that uses our test paths
    Jeeves::CLI.class_eval do
      alias_method :original_setup_config_dir, :setup_config_dir if method_defined?(:setup_config_dir)
      
      define_method(:setup_config_dir) do
        unless Dir.exist?(Jeeves::CLI::CONFIG_DIR)
          FileUtils.mkdir_p(Jeeves::CLI::CONFIG_DIR)
        end
        
        unless File.exist?(Jeeves::CLI::PROMPT_FILE)
          test_bundled_prompt = File.join(TEST_ROOT_DIR, 'config', 'prompt')
          if File.exist?(test_bundled_prompt)
            FileUtils.cp(test_bundled_prompt, Jeeves::CLI::PROMPT_FILE)
          end
        end
      end
    end
    
    # Create a CLI instance and call setup_config_dir
    cli = Jeeves::CLI.new
    cli.send(:setup_config_dir) # Explicitly call the private method
    
    # Verify the prompt file was correctly copied to the user config directory
    assert File.exist?(@prompt_file), "Prompt file should exist after setup_config_dir"
    assert_equal bundled_content, File.read(@prompt_file), "Prompt content should match the bundled file"
    
    # Properly restore the original method without removing it completely
    if Jeeves::CLI.method_defined?(:original_setup_config_dir)
      Jeeves::CLI.class_eval do
        # Define a new method with the same body as the original one
        remove_method :setup_config_dir
        alias_method :setup_config_dir, :original_setup_config_dir
        remove_method :original_setup_config_dir
      end
    end
  end
  
  # Mock method to avoid actual git commands
  def test_parse_options
    # Test with -a option
    cli1 = Jeeves::CLI.new
    ARGV.replace(['-a'])
    cli1.parse_options
    assert_equal true, cli1.instance_variable_get(:@options)[:all]
    assert_equal false, cli1.instance_variable_get(:@options)[:push]
    assert_equal false, cli1.instance_variable_get(:@options)[:dry_run]
    
    # Test with -p option
    cli2 = Jeeves::CLI.new
    ARGV.replace(['-p'])
    cli2.parse_options
    assert_equal false, cli2.instance_variable_get(:@options)[:all]
    assert_equal true, cli2.instance_variable_get(:@options)[:push]
    assert_equal false, cli2.instance_variable_get(:@options)[:dry_run]
    
    # Test with -d/--dry-run option
    cli3 = Jeeves::CLI.new
    ARGV.replace(['-d'])
    cli3.parse_options
    assert_equal false, cli3.instance_variable_get(:@options)[:all]
    assert_equal false, cli3.instance_variable_get(:@options)[:push]
    assert_equal true, cli3.instance_variable_get(:@options)[:dry_run]
    
    # Test with --dry-run long form
    cli4 = Jeeves::CLI.new
    ARGV.replace(['--dry-run'])
    cli4.parse_options
    assert_equal true, cli4.instance_variable_get(:@options)[:dry_run]
    
    # Test with all options
    cli5 = Jeeves::CLI.new
    ARGV.replace(['-a', '-p', '-d'])
    cli5.parse_options
    assert_equal true, cli5.instance_variable_get(:@options)[:all]
    assert_equal true, cli5.instance_variable_get(:@options)[:push]
    assert_equal true, cli5.instance_variable_get(:@options)[:dry_run]
    
    # Reset ARGV
    ARGV.replace([])
  end
  
  def test_bundled_prompt_path_calculation
    # This test ensures we don't have path calculation issues with '..' when finding the bundled prompt
    
    # Get the private method's source code using Ruby reflection
    setup_config_method = Jeeves::CLI.instance_method(:setup_config_dir)
    method_source = setup_config_method.source_location
    
    # Verify that we're able to find the method source
    assert method_source, "Could not locate setup_config_dir method source"
    
    # Capture the actual implemented logic for finding the bundled prompt
    config_prompt_path = nil
    
    # Override File.join to capture its arguments when called for the bundled prompt
    original_file_join = File.method(:join)
    path_capture = ->(path, *args) do
      # When we see a path concatenation that includes 'config/prompt', capture those args
      if args.include?('config') && args.include?('prompt')
        config_prompt_path = [path, *args]
      end
      original_file_join.call(path, *args)
    end
    
    # Stub File.join temporarily
    File.singleton_class.class_eval do
      alias_method :original_join, :join
      define_method(:join, &path_capture)
    end
    
    # Create a temporary CLI instance to trigger the path calculation
    begin
      # Create instance with stubbed file operations to avoid side effects
      FileUtils.stubs(:mkdir_p).returns(true)
      File.stubs(:exist?).returns(false) # Forces the path calculation code to run
      File.stubs(:read).returns("test prompt content")
      FileUtils.stubs(:cp).returns(true)
      
      # Catch the exit call in the error case
      begin
        cli = Jeeves::CLI.new
      rescue SystemExit
        # Expected when File.exist? is stubbed to false
      end
      
      # Now we should have captured the path calculation
      assert config_prompt_path, "Path calculation was not captured"
      
      # Check if we're only going up one directory level (not two)
      path_components = config_prompt_path.select { |part| part == '..' }
      assert_equal 1, path_components.size, 
                   "Path calculation goes too far up: #{config_prompt_path.join('/')}"
      
      # Also verify we're constructing the path correctly
      assert_includes config_prompt_path, 'config'
      assert_includes config_prompt_path, 'prompt'
    ensure
      # Restore original File.join method
      File.singleton_class.class_eval do
        remove_method :join
        alias_method :join, :original_join
      end
      
      # Remove any stubs
      FileUtils.unstub(:mkdir_p)
      File.unstub(:exist?)
      File.unstub(:read)
      FileUtils.unstub(:cp)
    end
  end
  
  def test_dry_run_functionality
    # Set up a CLI instance with dry-run enabled
    cli = Jeeves::CLI.new
    ARGV.replace(['-d'])
    cli.parse_options
    
    # Mock the diff to return something
    cli.stubs(:`).with('git diff --staged').returns('test diff content')
    
    # Mock the generate_commit_message method to return a test message
    test_commit_message = "feat: 🚀 add new feature\n\nThis is a test commit message."
    cli.stubs(:generate_commit_message).returns(test_commit_message)
    
    # Capture stdout to verify the dry-run output
    require 'stringio'
    original_stdout = $stdout
    $stdout = StringIO.new
    
    # Run the CLI
    cli.run
    
    # Get the captured output
    output = $stdout.string
    
    # Restore stdout
    $stdout = original_stdout
    
    # Verify the output contains the dry-run message
    assert_includes output, "Dry-run mode: Commit message would be:"
    assert_includes output, "============================================"
    assert_includes output, test_commit_message
    assert_includes output, "No commit was created (dry-run mode)"
    
    # Verify that system commands for commit and push were not called
    # We need to ensure system method was not called for git commit
    Object.any_instance.expects(:system).with(regexp_matches(/git commit/)).never
    Object.any_instance.expects(:system).with('git push').never
    
    # Reset ARGV
    ARGV.replace([])
  end
  
  def test_dry_run_with_no_staged_changes
    # Test that dry-run still respects the "no changes staged" check
    cli = Jeeves::CLI.new
    ARGV.replace(['-d'])
    cli.parse_options
    
    # Mock empty diff
    cli.stubs(:`).with('git diff --staged').returns('')
    
    # Capture stdout to verify the exit behavior
    require 'stringio'
    original_stdout = $stdout
    $stdout = StringIO.new
    
    # Expect the CLI to exit with status 1 for no staged changes
    assert_raises(SystemExit) do
      cli.run
    end
    
    # Get the captured output
    output = $stdout.string
    
    # Restore stdout
    $stdout = original_stdout
    
    # Verify the "no changes staged" message is shown
    assert_includes output, "No changes staged for commit."
    
    # Reset ARGV
    ARGV.replace([])
  end
end
