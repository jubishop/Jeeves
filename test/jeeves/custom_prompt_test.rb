require_relative '../test_helper'
require 'fileutils'

class CustomPromptTest < Minitest::Test
  def setup
    # Use our common test environment setup
    setup_test_environment
    
    # Create a global prompt file
    @global_prompt_file = File.join(@test_config_dir, 'prompt')
    File.write(@global_prompt_file, "Global prompt {{DIFF}}")
    
    # Create a simulated git repository
    @git_repo_dir = File.join(@test_root_dir, 'git_repo')
    FileUtils.mkdir_p(@git_repo_dir)
    
    # Create instance - will use our isolated test environment
    @cli = Jeeves::CLI.new
    
    # Stub git_root_dir to return our simulated repository
    @cli.stubs(:git_root_dir).returns(@git_repo_dir)
  end
  
  def teardown
    teardown_test_environment
  end
  
  def test_uses_repo_specific_prompt_when_available
    # Create a repo-specific prompt file
    repo_prompt_file = File.join(@git_repo_dir, '.jeeves_prompt')
    File.write(repo_prompt_file, "Repo-specific prompt {{DIFF}}")
    
    diff = "diff --git a/file.rb b/file.rb\n+new line"
    expected_message = "Test commit message"
    
    # Stub the HTTP request - We expect the repo-specific prompt to be used
    expected_prompt = "Repo-specific prompt #{diff}"
    
    # Prepare the expected request body
    request_body = {
      model: 'test_model',
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
  
  def test_fallbacks_to_global_prompt_when_repo_specific_not_available
    # No repo-specific prompt file is created, should use global prompt
    
    diff = "diff --git a/file.rb b/file.rb\n+new line"
    expected_message = "Test commit message"
    
    # Stub the HTTP request - We expect the global prompt to be used
    expected_prompt = "Global prompt #{diff}"
    
    # Prepare the expected request body
    request_body = {
      model: 'test_model',
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
end
