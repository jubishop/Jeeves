require_relative '../test_helper'

class LocalModelTest < Minitest::Test
  ENDPOINT = 'http://127.0.0.1:11434/api/chat'.freeze

  def setup
    setup_test_environment
    ENV['GIT_COMMIT_PROVIDER'] = 'ollama'
    File.write(Jeeves::CLI::PROMPT_FILE, 'Describe {{DIFF}}')
    @cli = Jeeves::CLI.new
    @cli.stubs(:git_root_dir).returns(nil)
  end

  def teardown
    teardown_test_environment
  end

  def test_local_generation_needs_no_api_key_and_ignores_cloud_model
    ENV.delete('OPENROUTER_API_KEY')
    ENV['GIT_COMMIT_MODEL'] = 'openai/gpt-6-luna'
    request = stub_request(:post, ENDPOINT).with do |req|
      body = JSON.parse(req.body)
      assert_nil req.headers['Authorization']
      assert_nil req.headers['Http-Referer']
      assert_equal 'qwen3.8:27b', body['model']
      assert_equal [{ 'role' => 'user', 'content' => 'Describe test diff' }], body['messages']
      assert_equal false, body['stream']
      assert_equal false, body['think']
      assert_equal 32_768, body.dig('options', 'num_ctx')
      assert_equal 1000, body.dig('options', 'num_predict')
      true
    end.to_return(body: { message: { content: "  fix: local message\n", thinking: 'Do not print this' } }.to_json)

    output, errors = capture_io do
      assert_equal 'fix: local message', generate
    end
    assert_empty output
    assert_empty errors
    assert_requested request
    assert_no_cloud_request
  end

  def test_persistent_local_model_and_context
    ENV['GIT_COMMIT_LOCAL_MODEL'] = 'qwen3.8:27b-mlx'
    ENV['GIT_COMMIT_LOCAL_CONTEXT'] = '65536'
    request = stub_local.with do |req|
      body = JSON.parse(req.body)
      assert_nil req.headers['Authorization']
      assert_nil req.headers['Http-Referer']
      body['model'] == 'qwen3.8:27b-mlx' && body.dig('options', 'num_ctx') == 65_536
    end
    assert_equal 'fix: local message', generate
    assert_requested request
  end

  def test_cli_model_overrides_persistent_model
    ENV['GIT_COMMIT_LOCAL_MODEL'] = 'configured-model'
    ARGV.replace(['--model', 'another-model'])
    @cli.parse_options
    request = stub_local.with { |req| JSON.parse(req.body)['model'] == 'another-model' }
    assert_equal 'fix: local message', generate
    assert_requested request
  end

  def test_local_flag_overrides_cloud_provider
    ENV['GIT_COMMIT_PROVIDER'] = 'openrouter'
    ARGV.replace(['--local'])
    @cli.parse_options
    request = stub_local
    generate
    assert_requested request
    assert_no_cloud_request
  end

  def test_cloud_override_preserves_cloud_model_and_authentication
    ARGV.replace(['--provider', 'openrouter'])
    @cli.parse_options
    request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')
              .with(headers: { 'Authorization' => 'Bearer test_api_key' }) do |req|
      JSON.parse(req.body)['model'] == 'test_model'
    end.to_return(body: { choices: [{ message: { content: 'fix: cloud message' } }] }.to_json)
    assert_equal 'fix: cloud message', generate
    assert_requested request
    assert_not_requested(:post, ENDPOINT)
  end

  def test_default_provider_remains_openrouter
    ENV.delete('GIT_COMMIT_PROVIDER')
    assert_equal 'Test commit message', generate
    assert_requested(:post, 'https://openrouter.ai/api/v1/chat/completions')
    assert_not_requested(:post, ENDPOINT)
  end

  def test_openrouter_still_requires_api_key
    ENV['GIT_COMMIT_PROVIDER'] = 'openrouter'
    ENV.delete('OPENROUTER_API_KEY')
    assert_generation_error('OPENROUTER_API_KEY')
    assert_no_cloud_request
  end

  def test_custom_https_server_and_path
    ENV['OLLAMA_HOST'] = 'https://local.example:8443/ollama/'
    request = stub_local('https://local.example:8443/ollama/api/chat')
    generate
    assert_requested request
  end

  def test_host_without_scheme
    ENV['OLLAMA_HOST'] = 'localhost:11435'
    request = stub_local('http://localhost:11435/api/chat')
    generate
    assert_requested request
  end

  def test_invalid_provider_fails_without_sending_diff
    ENV['GIT_COMMIT_PROVIDER'] = 'typo'
    assert_generation_error('GIT_COMMIT_PROVIDER')
    assert_no_cloud_request
    assert_not_requested(:post, ENDPOINT)
  end

  def test_invalid_context_fails_without_sending_diff
    ENV['GIT_COMMIT_LOCAL_CONTEXT'] = '0'
    assert_generation_error('GIT_COMMIT_LOCAL_CONTEXT')
    assert_not_requested(:post, ENDPOINT)
  end

  def test_invalid_host_fails_without_sending_diff
    ENV['OLLAMA_HOST'] = 'http://localhost:11434?invalid=true'
    assert_generation_error('OLLAMA_HOST')
    assert_no_cloud_request
  end

  def test_unsupported_url_scheme_is_rejected
    ENV['OLLAMA_HOST'] = 'ftp://localhost:11434'
    assert_generation_error('OLLAMA_HOST')
    assert_no_cloud_request
  end

  def test_unavailable_server_does_not_fall_back_to_cloud
    stub_request(:post, ENDPOINT).to_raise(Errno::ECONNREFUSED)
    assert_generation_error('ollama serve')
    assert_no_cloud_request
  end

  def test_timeout_does_not_fall_back_to_cloud
    stub_request(:post, ENDPOINT).to_timeout
    assert_generation_error('timed out')
    assert_no_cloud_request
  end

  def test_missing_model_explains_how_to_download_it
    stub_request(:post, ENDPOINT).to_return(status: 404, body: '{"error":"model not found"}')
    assert_generation_error('ollama pull')
    assert_no_cloud_request
  end

  def test_api_errors_are_reported
    stub_request(:post, ENDPOINT).to_return(status: 500, body: '{"error":"out of memory"}')
    assert_generation_error('out of memory')
  end

  def test_invalid_responses_never_become_commit_messages
    [
      'not JSON', 'null', '{}', '{"error":"load failed"}',
      '{"message":null}', '{"message":{"thinking":"reasoning only"}}',
      '{"message":{"content":null}}', '{"message":{"content":"  "}}',
      '{"message":{"content":["invalid"]}}',
      '{"message":{"content":"partial message"},"done_reason":"length"}'
    ].each do |body|
      stub_request(:post, ENDPOINT).to_return(body: body)
      assert_generation_error('Error:')
    end
    assert_no_cloud_request
  end

  def test_piped_diff_uses_persistent_settings_and_prints_only_message
    STDIN.stubs(:tty?).returns(false)
    STDIN.stubs(:read).returns('test diff')
    request = stub_local
    @cli.expects(:system).never
    output, errors = capture_io { @cli.run }
    assert_equal "fix: local message\n", output
    assert_empty errors
    assert_requested request
  end

  def test_first_run_setup_does_not_pollute_piped_output
    File.unlink(Jeeves::CLI::PROMPT_FILE)
    STDIN.stubs(:tty?).returns(false)
    STDIN.stubs(:read).returns('test diff')
    stub_local
    output, errors = capture_io { Jeeves::CLI.new.run }
    assert_equal "fix: local message\n", output
    assert_includes errors, 'Prompt file installed successfully.'
  end

  def test_dry_run_uses_local_provider_without_committing
    ARGV.replace(['--dry-run'])
    @cli.stubs(:`).with('git diff --staged').returns('test diff')
    @cli.expects(:system).never
    stub_local
    output, = capture_io { @cli.run }
    assert_includes output, 'Using provider: ollama'
    assert_includes output, 'fix: local message'
    assert_includes output, 'No commit was created'
  end

  def test_failed_generation_does_not_commit_or_push
    ARGV.replace(['--push'])
    @cli.stubs(:`).with('git diff --staged').returns('test diff')
    @cli.expects(:system).never
    stub_request(:post, ENDPOINT).to_raise(Errno::ECONNREFUSED)
    capture_io { assert_raises(SystemExit) { @cli.run } }
    assert_no_cloud_request
  end

  private

  def generate
    @cli.send(:generate_commit_message, 'test diff', suppress_output: true)
  end

  def stub_local(endpoint = ENDPOINT)
    stub_request(:post, endpoint).to_return(body: { message: { content: 'fix: local message' } }.to_json)
  end

  def assert_generation_error(text)
    output, errors = capture_io do
      assert_equal 1, assert_raises(SystemExit) { generate }.status
    end
    assert_empty output
    assert_includes errors, text
  end

  def assert_no_cloud_request
    assert_not_requested(:post, 'https://openrouter.ai/api/v1/chat/completions')
  end
end
