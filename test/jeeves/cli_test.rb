# frozen_string_literal: true

require_relative '../test_helper'

class CLITest < Minitest::Test
  LOCAL = 'http://127.0.0.1:11434/api/chat'
  CLOUD = 'https://openrouter.ai/api/v1/chat/completions'

  def test_local_settings_and_literal_prompt_reach_server_without_cloud_credentials
    with_cli_environment do |env, directory|
      env.delete('OPENROUTER_API_KEY')
      env['GIT_COMMIT_LOCAL_CONTEXT'] = '65536'
      diff = "+replacement='\\1'; match='\\&'"
      request = stub_request(:post, LOCAL).with do |http|
        body = JSON.parse(http.body)
        assert_nil http.headers['Authorization']
        assert_nil http.headers['Http-Referer']
        assert_equal 'local-model', body['model']
        assert_equal [{ 'role' => 'user', 'content' => "Describe #{diff}" }], body['messages']
        assert_equal false, body['stream']
        assert_equal false, body['think']
        assert_equal 65_536, body.dig('options', 'num_ctx')
        true
      end.to_return(body: { message: { content: 'fix: local message', thinking: 'ignored' } }.to_json)
      assert_equal [0, "🐛 fix: local message\n", ''], invoke(env, directory, diff: diff)
      assert_requested request
      assert_not_requested(:post, CLOUD)
    end
  end

  def test_local_and_model_flags_override_saved_cloud_settings
    with_cli_environment do |env, directory|
      env['GIT_COMMIT_PROVIDER'] = 'openrouter'
      request = local_request.with { |http| JSON.parse(http.body)['model'] == 'override' }
      assert_equal 0, invoke(env, directory, args: %w[--local --model override]).first
      assert_requested request
    end
  end

  def test_cloud_override_preserves_cloud_model_and_authentication
    with_cli_environment do |env, directory|
      env['GIT_COMMIT_LOCAL_CONTEXT'] = 'invalid-unused-local-setting'
      request = cloud_request.with(headers: { 'Authorization' => 'Bearer test-key' }) do |http|
        JSON.parse(http.body)['model'] == 'cloud-model'
      end
      assert_equal 0, invoke(env, directory, args: %w[--provider openrouter]).first
      assert_requested request
      assert_not_requested(:post, LOCAL)
    end
  end

  def test_defaults_use_openrouter_and_xai_without_stop_parameter
    with_cli_environment do |env, directory|
      env.delete('GIT_COMMIT_PROVIDER')
      env.delete('GIT_COMMIT_MODEL')
      request = cloud_request.with do |http|
        body = JSON.parse(http.body)
        body['model'] == 'x-ai/grok-code-fast-1' && !body.key?('stop')
      end
      assert_equal 0, invoke(env, directory).first
      assert_requested request
    end
  end

  def test_reasoning_cloud_models_receive_system_instruction
    with_cli_environment do |env, directory|
      env['GIT_COMMIT_PROVIDER'] = 'openrouter'
      env['GIT_COMMIT_MODEL'] = 'openai/gpt-5-mini'
      request = cloud_request.with do |http|
        body = JSON.parse(http.body)
        body['messages'].first['role'] == 'system' && body['stop'] == ['END_COMMIT']
      end
      assert_equal 0, invoke(env, directory).first
      assert_requested request
    end
  end

  def test_invalid_configuration_fails_before_network_access
    cases = [
      ['GIT_COMMIT_PROVIDER', 'typo'], ['GIT_COMMIT_LOCAL_MODEL', ' '],
      ['GIT_COMMIT_LOCAL_CONTEXT', '0'], ['GIT_COMMIT_LOCAL_CONTEXT', 'abc'],
      ['GIT_COMMIT_MAX_DIFF_BYTES', '-1'], ['GIT_COMMIT_MESSAGE_FORMAT', 'json'],
      ['OLLAMA_HOST', 'http://localhost:11434?invalid=true'],
      ['OLLAMA_HOST', 'ftp://localhost'], ['OLLAMA_HOST', 'http://user:password@localhost']
    ]
    cases.each do |key, value|
      with_cli_environment do |env, directory|
        env[key] = value
        code, output, errors = invoke(env, directory)
        assert_equal 1, code, "#{key}=#{value}"
        assert_empty output
        assert_includes errors, 'Error:'
      end
    end
    assert_not_requested(:post, LOCAL)
    assert_not_requested(:post, CLOUD)
  end

  def test_cloud_requires_api_key
    with_cli_environment do |env, directory|
      env['GIT_COMMIT_PROVIDER'] = 'openrouter'
      env.delete('OPENROUTER_API_KEY')
      code, output, errors = invoke(env, directory)
      assert_equal 1, code
      assert_empty output
      assert_includes errors, 'OPENROUTER_API_KEY'
    end
  end

  def test_custom_local_urls
    { 'localhost:11435' => 'http://localhost:11435/api/chat',
      'https://local.example:8443/ollama/' => 'https://local.example:8443/ollama/api/chat' }.each do |host, endpoint|
      with_cli_environment do |env, directory|
        env['OLLAMA_HOST'] = host
        request = local_request(endpoint)
        assert_equal 0, invoke(env, directory).first
        assert_requested request
      end
    end
  end

  def test_local_failures_do_not_fall_back_to_cloud
    responses = [
      { status: 404, body: '{"error":"model not found"}' },
      { status: 500, body: '{"error":"out of memory"}' },
      { body: 'not JSON' }, { body: 'null' }, { body: '{}' },
      { body: '{"error":"load failed"}' }, { body: '{"message":null}' },
      { body: '{"message":{"thinking":"reasoning only"}}' },
      { body: '{"message":{"content":null}}' }, { body: '{"message":{"content":"  "}}' },
      { body: '{"message":{"content":["invalid"]}}' },
      { body: '{"message":{"content":"fix: partial"},"done_reason":"length"}' }
    ]
    responses.each do |response|
      with_cli_environment do |env, directory|
        stub_request(:post, LOCAL).to_return(**response)
        code, output, errors = invoke(env, directory)
        assert_equal 1, code, response.inspect
        assert_empty output
        assert_includes errors, 'Error:'
        assert_includes errors, 'ollama pull local-model' if response[:status] == 404
      end
    end
    assert_not_requested(:post, CLOUD)
  end

  def test_local_connection_and_timeout_errors_are_actionable
    [Errno::ECONNREFUSED, Net::ReadTimeout, Net::OpenTimeout, SocketError].each do |error|
      with_cli_environment do |env, directory|
        stub_request(:post, LOCAL).to_raise(error)
        code, output, errors = invoke(env, directory)
        assert_equal 1, code
        assert_empty output
        assert_match(/Ollama|OLLAMA_HOST/, errors)
      end
    end
    assert_not_requested(:post, CLOUD)
  end

  def test_broken_http_and_tls_connections_return_clean_errors
    [EOFError, Net::HTTPBadResponse, OpenSSL::SSL::SSLError].each do |error|
      with_cli_environment do |env, directory|
        stub_request(:post, LOCAL).to_raise(error)
        code, output, errors = invoke(env, directory)
        assert_equal 1, code
        assert_empty output
        assert_includes errors, 'connection failed'
      end
    end
    assert_not_requested(:post, CLOUD)
  end

  def test_local_context_budget_shortens_input_with_a_warning
    with_cli_environment do |env, directory|
      env['GIT_COMMIT_LOCAL_CONTEXT'] = '2048'
      request = local_request.with do |http|
        JSON.parse(http.body).dig('messages', 0, 'content').bytesize <= 2048 - 1256
      end
      code, _output, errors = invoke(env, directory, diff: 'x' * 1000)
      assert_equal 0, code, errors
      assert_includes errors, 'Warning: diff shortened'
      assert_requested request
    end
  end

  def test_cloud_empty_truncated_and_malformed_responses_are_rejected
    ['null', '{}', '{"choices":[]}', '{"choices":[{"message":{"content":""}}]}',
     '{"choices":[{"message":{"content":"fix: partial"},"finish_reason":"length"}]}'].each do |body|
      with_cli_environment do |env, directory|
        env['GIT_COMMIT_PROVIDER'] = 'openrouter'
        stub_request(:post, CLOUD).to_return(body: body)
        code, output, errors = invoke(env, directory)
        assert_equal 1, code
        assert_empty output
        assert_includes errors, 'Error:'
      end
    end
  end

  def test_message_format_validation_and_plain_opt_out
    with_cli_environment do |env, directory|
      local_request(content: 'A custom subject')
      assert_equal 1, invoke(env, directory).first
      env['GIT_COMMIT_MESSAGE_FORMAT'] = 'plain'
      assert_equal [0, "A custom subject\n", ''], invoke(env, directory)
    end
  end

  def test_emoji_is_normalized_to_type_without_rewriting_body
    with_cli_environment do |env, directory|
      local_request(content: "✨ fix(client)!: preserve zero\n\nKeep 0 instead of choosing 3.")
      assert_equal [0, "🐛 fix(client)!: preserve zero\n\nKeep 0 instead of choosing 3.\n", ''], invoke(env, directory)
    end
  end

  def test_conventional_message_separates_subject_and_body
    with_cli_environment do |env, directory|
      local_request(content: "fix: preserve zero\nKeep 0 instead of choosing 3.")
      assert_equal [0, "🐛 fix: preserve zero\n\nKeep 0 instead of choosing 3.\n", ''], invoke(env, directory)
    end
  end

  def test_prompt_requires_diff_placeholder
    with_cli_environment do |env, directory|
      File.write(File.join(directory, '.config/jeeves/prompt'), 'Missing placeholder')
      code, _output, errors = invoke(env, directory)
      assert_equal 1, code
      assert_includes errors, '{{DIFF}}'
      assert_not_requested(:post, LOCAL)
    end
  end

  def test_invalid_options_and_empty_stdin_return_failure
    with_cli_environment do |env, directory|
      [ ['--provider', 'typo'], ['--unknown'], ['extra'] ].each do |args|
        assert_equal 1, invoke(env, directory, args: args).first
      end
      assert_equal 1, invoke(env, directory, diff: '').first
      assert_equal 1, invoke(env, directory, diff: '  ').first
      assert_not_requested(:post, LOCAL)
    end
  end

  def test_version_and_help_need_no_provider_or_configuration
    with_cli_environment do |env, directory|
      env['GIT_COMMIT_PROVIDER'] = 'invalid'
      assert_equal [0, "#{Jeeves::VERSION}\n", ''], invoke(env, directory, args: ['--version'])
      code, output, errors = invoke(env, directory, args: ['--help'])
      assert_equal 0, code
      assert_includes output, '--provider'
      assert_empty errors
    end
  end

  private

  def local_request(endpoint = LOCAL, content: 'fix: local message')
    stub_request(:post, endpoint).to_return(body: { message: { content: content } }.to_json)
  end

  def cloud_request
    stub_request(:post, CLOUD).to_return(body: { choices: [{ message: { content: 'fix: cloud message' } }] }.to_json)
  end
end
