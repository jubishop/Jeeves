require 'test_helper'
require 'webmock/minitest'

class CommitMessageTest < Minitest::Test
  def setup
    # Create a temporary directory for test config
    @original_config_dir = Jeeves::CLI::CONFIG_DIR
    @test_config_dir = File.join(Dir.tmpdir, "jeeves_test_#{Time.now.to_i}")
    FileUtils.mkdir_p(@test_config_dir)
    
    # Stub the CONFIG_DIR constant
    Jeeves::CLI.send(:remove_const, :CONFIG_DIR)
    Jeeves::CLI.const_set(:CONFIG_DIR, @test_config_dir)
    
    # Create a test prompt file with the exact format we need
    @prompt_file = File.join(@test_config_dir, 'prompt')
    File.write(@prompt_file, <<-PROMPT
Generate a git commit message based on the following diff.

The commit message should:
- Start with an appropriate gitmoji based on the nature of the changes
- Follow the Conventional Commits format (https://www.conventionalcommits.org/en/v1.0.0/)
- Explain WHAT changed, WHY it changed, and HOW it improves or fixes the current state
- Assume the audience is educated software engineers

Example format:
:emoji: type(scope): concise description

Detailed explanation of the changes, why they were necessary, and their impact.

Additional context or technical details when relevant.

DIFF:
{{DIFF}}
PROMPT
    )
    
    # Set test environment variables
    @original_api_key = ENV['OPENROUTER_API_KEY']
    ENV['OPENROUTER_API_KEY'] = 'test_api_key'
    
    @original_model = ENV['GIT_COMMIT_MODEL']
    ENV['GIT_COMMIT_MODEL'] = 'test-model'
    
    # Create instance
    @cli = Jeeves::CLI.new
  end
  
  def teardown
    # Restore original CONFIG_DIR
    Jeeves::CLI.send(:remove_const, :CONFIG_DIR)
    Jeeves::CLI.const_set(:CONFIG_DIR, @original_config_dir)
    
    # Clean up test directory
    FileUtils.rm_rf(@test_config_dir) if File.exist?(@test_config_dir)
    
    # Restore environment variables
    ENV['OPENROUTER_API_KEY'] = @original_api_key
    ENV['GIT_COMMIT_MODEL'] = @original_model
  end
  
  def test_generate_commit_message
    diff = "diff --git a/file.rb b/file.rb\n+new line"
    expected_message = "Test commit message"
    
    # Stub the HTTP request
    expected_prompt = File.read(@prompt_file).gsub('{{DIFF}}', diff)
    
    # Prepare the exact request body we expect
    request_body = {
      model: 'test-model',
      messages: [{ role: 'user', content: expected_prompt }],
      max_tokens: 500
    }

    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
      .with(
        body: request_body.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => 'Bearer test_api_key',
          'HTTP-Referer' => 'https://github.com/jeeves-git-commit'
        }
      )
      .to_return(
        status: 200,
        body: {
          choices: [{ message: { content: expected_message } }]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    # Call method and check result
    result = @cli.send(:generate_commit_message, diff)
    assert_equal expected_message, result
  end
  
  def test_api_error_handling
    diff = "diff --git a/file.rb b/file.rb\n+new line"
    
    # Stub the HTTP request to return an error
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
      .to_return(
        status: 400,
        body: { error: "Bad request" }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    # Expect system exit
    assert_raises(SystemExit) do
      @cli.send(:generate_commit_message, diff)
    end
  end
end
