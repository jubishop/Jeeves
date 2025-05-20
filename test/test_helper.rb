# Define TESTING_MODE to prevent exit calls during tests
TESTING_MODE = true

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

# Helper to create a clean test environment
class Minitest::Test
  def setup_test_environment
    # Store original ENV values
    @original_env = {}
    ['OPENROUTER_API_KEY', 'GIT_COMMIT_MODEL'].each do |key|
      @original_env[key] = ENV[key]
    end
    
    # Set test ENV values
    ENV['OPENROUTER_API_KEY'] = 'test_api_key'
    ENV['GIT_COMMIT_MODEL'] = 'test_model'
    
    # Stub the API response
    stub_openrouter_api
    
    # Stub system calls
    stub_system_calls
    
    # Create test prompt file in config directory
    config_dir = File.expand_path('../../config', __FILE__)
    FileUtils.mkdir_p(config_dir) unless Dir.exist?(config_dir)
    prompt_file = File.join(config_dir, 'prompt')
    File.write(prompt_file, "Test prompt content with {{DIFF}} placeholder") unless File.exist?(prompt_file)
  end
  
  def teardown_test_environment
    # Restore original ENV values
    @original_env.each do |key, value|
      ENV[key] = value
    end
  end
end
