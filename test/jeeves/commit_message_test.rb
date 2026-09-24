require_relative '../test_helper'
require 'webmock/minitest'

class CommitMessageTest < Minitest::Test
  def setup
    # Use our common test environment setup which now handles:
    # - Creating an isolated test environment
    # - Setting up test directories
    # - Overriding CONFIG_DIR to use test paths
    # - Stubbing API calls and system commands
    setup_test_environment
    
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
    
    # Create instance - will use our isolated test environment
    @cli = Jeeves::CLI.new
  end
  
  def teardown
    # Use the common teardown_test_environment which now handles:
    # - Restoring CONFIG_DIR constant
    # - Cleaning up all test directories
    # - Restoring ENV variables
    teardown_test_environment
  end
  
  def test_generate_commit_message
    diff = "diff --git a/file.rb b/file.rb\n+new line"
    expected_message = "Test commit message"
    
    # Stub the HTTP request
    expected_prompt = File.read(@prompt_file).gsub('{{DIFF}}', diff)
    
    # Prepare the exact request body we expect
    request_body = {
      model: 'test_model',
      messages: [{ role: 'user', content: expected_prompt }],
      max_tokens: 1000,
      stop: ['END_COMMIT']
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
    assert_requested(:post, 'https://openrouter.ai/api/v1/chat/completions', body: request_body.to_json)
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

  def test_default_xai_model_omits_unsupported_stop_parameter
    ENV.delete('GIT_COMMIT_MODEL')
    request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').with do |req|
      body = JSON.parse(req.body)
      body['model'] == 'x-ai/grok-code-fast-1' && !body.key?('stop')
    end.to_return(body: { choices: [{ message: { content: 'fix: xai message' } }] }.to_json)
    assert_equal 'fix: xai message', @cli.send(:generate_commit_message, 'test diff', suppress_output: true)
    assert_requested request
  end

  def test_reasoning_model_keeps_output_format_instructions
    ENV['GIT_COMMIT_MODEL'] = 'openai/gpt-5-mini'
    request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').with do |req|
      body = JSON.parse(req.body)
      body['messages'].first['role'] == 'system' && body['stop'] == ['END_COMMIT']
    end.to_return(body: { choices: [{ message: { content: 'fix: reasoning model message' } }] }.to_json)
    assert_equal 'fix: reasoning model message', @cli.send(:generate_commit_message, 'test diff', suppress_output: true)
    assert_requested request
  end
end
