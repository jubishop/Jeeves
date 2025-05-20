# Define TESTING_MODE to prevent exit calls during tests
TESTING_MODE = true

# Required for Dir.tmpdir
require 'tmpdir'

# Use a completely isolated test environment
TEST_ROOT_DIR = File.join(Dir.tmpdir, "jeeves_test_root_#{Time.now.to_i}")
FileUtils.mkdir_p(TEST_ROOT_DIR)

# Clean up the test root directory when the process exits
at_exit do
  FileUtils.rm_rf(TEST_ROOT_DIR) if Dir.exist?(TEST_ROOT_DIR)
end

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'jeeves'
require 'minitest/autorun'
require 'minitest/pride' # For colorized output
require 'webmock/minitest' # For mocking HTTP requests
require 'mocha/minitest' # For stubbing methods
require 'fileutils'
require 'tempfile'

# Ensure WebMock is properly configured
WebMock.disable_net_connect!(allow_localhost: true)

# Set up stub for API responses
def stub_openrouter_api
  # Simply stub the request - WebMock will handle duplicates
  stub_request(:post, "https://openrouter.ai/api/v1/chat/completions").
    to_return(status: 200, body: {
      "choices": [{
        "message": {
          "content": "Test commit message"
        }
      }]
    }.to_json, headers: {'Content-Type' => 'application/json'})
end

# Mock system calls to git
def stub_system_calls
  # Stub system calls to avoid actual git operations
  Object.any_instance.stubs(:system).returns(true)
  Object.any_instance.stubs(:`).returns("mock diff output")
end

# Helper methods for test isolation
def create_isolated_project_structure
  # Create isolated test directories that mirror the real project structure
  test_config_dir = File.join(TEST_ROOT_DIR, 'config')
  FileUtils.mkdir_p(test_config_dir)
  
  # Create a test prompt file with proper content
  test_prompt_content = File.read(File.expand_path('../../config/prompt', __FILE__))
  File.write(File.join(test_config_dir, 'prompt'), test_prompt_content)
  
  # Return the test root directory path
  TEST_ROOT_DIR
end

# Store the real Jeeves CONFIG_DIR constant to avoid affecting real files
REAL_CONFIG_DIR = Jeeves::CLI::CONFIG_DIR

# Helper to create a clean test environment
class Minitest::Test
  def setup_test_environment
    # Create an isolated test environment
    @test_root_dir = create_isolated_project_structure
    
    # Store original ENV values and constants
    @original_env = {}
    ['OPENROUTER_API_KEY', 'GIT_COMMIT_MODEL'].each do |key|
      @original_env[key] = ENV[key]
    end
    
    # Save the original CONFIG_DIR value
    @original_config_dir = REAL_CONFIG_DIR
    
    # Create a test-specific config directory
    @test_config_dir = File.join(@test_root_dir, 'user_config')
    FileUtils.mkdir_p(@test_config_dir)
    
    # Override the CONFIG_DIR constant to use our test directory instead of the real user config
    Jeeves::CLI.send(:remove_const, :CONFIG_DIR) if Jeeves::CLI.const_defined?(:CONFIG_DIR)
    Jeeves::CLI.const_set(:CONFIG_DIR, @test_config_dir)
    
    # Also store and override the PROMPT_FILE constant to use our test directory
    @original_prompt_file = Jeeves::CLI::PROMPT_FILE if Jeeves::CLI.const_defined?(:PROMPT_FILE)
    Jeeves::CLI.send(:remove_const, :PROMPT_FILE) if Jeeves::CLI.const_defined?(:PROMPT_FILE)
    Jeeves::CLI.const_set(:PROMPT_FILE, File.join(@test_config_dir, 'prompt'))
    
    # Set test ENV values
    ENV['OPENROUTER_API_KEY'] = 'test_api_key'
    ENV['GIT_COMMIT_MODEL'] = 'test_model'
    
    # Stub the API response
    stub_openrouter_api
    
    # Stub system calls
    stub_system_calls
  end
  
  def teardown_test_environment
    # Restore the original CONFIG_DIR constant
    if defined?(@original_config_dir) && Jeeves::CLI.const_defined?(:CONFIG_DIR)
      Jeeves::CLI.send(:remove_const, :CONFIG_DIR)
      Jeeves::CLI.const_set(:CONFIG_DIR, @original_config_dir)
    end
    
    # Restore the original PROMPT_FILE constant
    if defined?(@original_prompt_file) && Jeeves::CLI.const_defined?(:PROMPT_FILE)
      Jeeves::CLI.send(:remove_const, :PROMPT_FILE)
      Jeeves::CLI.const_set(:PROMPT_FILE, @original_prompt_file)
    end
    
    # Restore original ENV values
    @original_env.each do |key, value|
      ENV[key] = value
    end
    
    # Clean up test directories for this test
    FileUtils.rm_rf(@test_config_dir) if defined?(@test_config_dir) && @test_config_dir && Dir.exist?(@test_config_dir)
  end
end
