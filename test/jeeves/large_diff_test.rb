# frozen_string_literal: true

require_relative '../test_helper'

class LargeDiffTest < Minitest::Test
  LOCAL = 'http://127.0.0.1:11434/api/chat'
  CLOUD = 'https://openrouter.ai/api/v1/chat/completions'

  def test_default_local_context_is_64k_and_preserves_a_diff_above_the_old_limit
    with_cli_environment do |env, directory|
      diff = "+change\n" * 5000
      request = local_request do |body|
        assert_equal 65_536, body.dig('options', 'num_ctx')
        assert_equal "Describe #{diff}", body.dig('messages', 0, 'content')
      end
      assert_equal [0, "🐛 fix: handle changes\n", ''], invoke(env, directory, diff: diff)
      assert_requested request, times: 1
    end
  end

  def test_local_shortening_accounts_for_template_and_repeated_placeholders
    with_cli_environment do |env, directory|
      env['GIT_COMMIT_LOCAL_CONTEXT'] = '4096'
      template = "Instructions #{'p' * 500}\n{{DIFF}}\nAgain: {{DIFF}}"
      File.write(File.join(directory, '.config/jeeves/prompt'), template)
      request = local_request do |body|
        prompt = body.dig('messages', 0, 'content')
        assert_operator prompt.bytesize, :<=, 4096 - 1256
        assert_includes prompt, 'Instructions'
        assert_includes prompt, 'shortened'
      end
      code, output, errors = invoke(env, directory, diff: "+change\n" * 10_000)
      assert_equal 0, code, errors
      assert_equal "🐛 fix: handle changes\n", output
      assert_match(/Warning:.*shortened.*80000.*bytes/, errors)
      assert_requested request, times: 1
      assert_not_requested(:post, CLOUD)
    end
  end

  def test_context_is_removed_before_any_changed_lines
    with_cli_environment do |env, directory|
      env['GIT_COMMIT_MAX_DIFF_BYTES'] = '700'
      diff = "diff --git a/file b/file\n--- a/file\n+++ b/file\n@@ -1,100 +1,100 @@\n"
      diff += " unchanged context\n" * 100
      diff += "-old behavior\n+new behavior\n"
      local_request do |body|
        prompt = body.dig('messages', 0, 'content')
        assert_includes prompt, '-old behavior'
        assert_includes prompt, '+new behavior'
        refute_includes prompt, 'unchanged context'
        assert_includes prompt, 'shortened'
        assert_operator prompt.delete_prefix('Describe ').bytesize, :<=, 700
      end
      code, _output, errors = invoke(env, directory, diff: diff)
      assert_equal 0, code, errors
      assert_includes errors, 'Warning:'
    end
  end

  def test_large_files_share_space_and_a_small_late_file_is_preserved
    with_cli_environment do |env, directory|
      env['GIT_COMMIT_MAX_DIFF_BYTES'] = '1800'
      first = patch('first.rb', ("-old first\n" * 200) + ("+new first\n" * 200))
      second = patch('second.rb', ("-old second\n" * 200) + ("+new second\n" * 200))
      last = patch('z-last.rb', "-allow_all\n+check_permission\n")
      local_request do |body|
        prompt = body.dig('messages', 0, 'content')
        assert_operator prompt.delete_prefix('Describe ').bytesize, :<=, 1800
        %w[first.rb second.rb z-last.rb].each { |name| assert_includes prompt, "diff --git a/#{name} b/#{name}" }
        ['-old first', '+new first', '-old second', '+new second', last].each do |change|
          assert_includes prompt, change
        end
        assert_includes prompt, 'omitted'
      end
      code, _output, errors = invoke(env, directory, diff: first + second + last)
      assert_equal 0, code, errors
    end
  end

  def test_cloud_byte_limit_shortens_complete_stdin_including_its_tail
    with_cli_environment do |env, directory|
      env['GIT_COMMIT_PROVIDER'] = 'openrouter'
      env['GIT_COMMIT_MAX_DIFF_BYTES'] = '600'
      diff = "+start\n" + ("+middle\n" * 10_000) + "+last_change\n"
      request = stub_request(:post, CLOUD).with do |http|
        prompt = JSON.parse(http.body).dig('messages', 0, 'content')
        assert_operator prompt.delete_prefix('Describe ').bytesize, :<=, 600
        assert_includes prompt, '+start'
        assert_includes prompt, '+last_change'
        true
      end.to_return(body: { choices: [{ message: { content: 'fix: handle changes' } }] }.to_json)
      code, _output, errors = invoke(env, directory, diff: diff)
      assert_equal 0, code, errors
      assert_includes errors, diff.bytesize.to_s
      assert_requested request, times: 1
      assert_not_requested(:post, LOCAL)
    end
  end

  def test_shortening_keeps_utf8_valid_even_for_a_single_long_line
    with_cli_environment do |env, directory|
      env['GIT_COMMIT_MAX_DIFF_BYTES'] = '501'
      local_request do |body|
        prompt = body.dig('messages', 0, 'content')
        assert prompt.valid_encoding?
        assert_includes prompt, '🐠'
        refute_includes prompt, "\uFFFD"
        assert_operator prompt.delete_prefix('Describe ').bytesize, :<=, 501
        assert_includes prompt, 'omitted'
      end
      code, _output, errors = invoke(env, directory, diff: '+' + ('🐠' * 1000))
      assert_equal 0, code, errors
    end
  end

  def test_space_prefixed_changes_in_combined_diffs_are_not_removed_as_context
    with_cli_environment do |env, directory|
      env['GIT_COMMIT_MAX_DIFF_BYTES'] = '700'
      diff = "diff --cc file.rb\nindex 123,456..789\n--- a/file.rb\n+++ b/file.rb\n@@@ -1,100 -1,100 +1,100 @@@\n"
      diff += "  unchanged\n" * 100
      diff += " -removed from second parent\n +added against second parent\n"
      local_request do |body|
        prompt = body.dig('messages', 0, 'content')
        assert_includes prompt, ' -removed from second parent'
        assert_includes prompt, ' +added against second parent'
        refute_includes prompt, '  unchanged'
      end
      code, _output, errors = invoke(env, directory, diff: diff)
      assert_equal 0, code, errors
    end
  end

  def test_all_hunk_headers_and_changes_share_space_when_they_fit
    with_cli_environment do |env, directory|
      env['GIT_COMMIT_MAX_DIFF_BYTES'] = '1800'
      function_name = 'long_function_' + ('x' * 250)
      diff = "diff --git a/file.rb b/file.rb\n--- a/file.rb\n+++ b/file.rb\n"
      [1, 200, 400].each do |start|
        diff += "@@ -#{start},100 +#{start},100 @@ #{function_name}_#{start}\n"
        diff += ("-old_#{start}\n" * 100) + ("+new_#{start}\n" * 100)
      end
      local_request do |body|
        prompt = body.dig('messages', 0, 'content')
        [1, 200, 400].each do |start|
          assert_includes prompt, "@@ -#{start},100 +#{start},100 @@ #{function_name}_#{start}\n"
          assert_includes prompt, "-old_#{start}"
          assert_includes prompt, "+new_#{start}"
        end
      end
      code, _output, errors = invoke(env, directory, diff: diff)
      assert_equal 0, code, errors
    end
  end

  def test_more_file_headers_than_fit_are_explicitly_marked_as_incomplete
    with_cli_environment do |env, directory|
      env['GIT_COMMIT_MAX_DIFF_BYTES'] = '700'
      diff = (1..100).map { |index| patch("file#{index}.rb", "+change\n") }.join
      local_request do |body|
        prompt = body.dig('messages', 0, 'content')
        assert_operator prompt.delete_prefix('Describe ').bytesize, :<=, 700
        assert_includes prompt, 'may omit files'
        assert_includes prompt, 'file1.rb'
        assert_includes prompt, 'file100.rb'
      end
      code, _output, errors = invoke(env, directory, diff: diff)
      assert_equal 0, code, errors
      assert_includes errors, 'may miss changes'
    end
  end

  def test_a_byte_limit_too_small_for_the_omission_notice_fails_clearly
    with_cli_environment do |env, directory|
      env['GIT_COMMIT_MAX_DIFF_BYTES'] = '10'
      code, output, errors = invoke(env, directory, diff: '+change' * 100)
      assert_equal 1, code
      assert_empty output
      assert_includes errors, 'Too little room'
      assert_includes errors, 'GIT_COMMIT_MAX_DIFF_BYTES'
      assert_not_requested(:post, LOCAL)
    end
  end

  def test_invalid_utf8_after_the_byte_limit_is_rejected_before_generation
    with_cli_environment do |env, directory|
      env['GIT_COMMIT_MAX_DIFF_BYTES'] = '500'
      code, output, errors = invoke(env, directory, diff: ('x' * 1000) + "\xFF".b)
      assert_equal 1, code
      assert_empty output
      assert_includes errors, 'UTF-8'
      assert_not_requested(:post, LOCAL)
    end
  end

  def test_unusable_context_reports_that_instructions_leave_no_room
    with_cli_environment do |env, directory|
      env['GIT_COMMIT_LOCAL_CONTEXT'] = '1300'
      File.write(File.join(directory, '.config/jeeves/prompt'), "#{'p' * 100} {{DIFF}}")
      code, output, errors = invoke(env, directory)
      assert_equal 1, code
      assert_empty output
      assert_includes errors, 'GIT_COMMIT_LOCAL_CONTEXT'
      assert_includes errors, 'prompt'
      assert_not_requested(:post, LOCAL)
    end
  end

  private

  def patch(name, changes)
    "diff --git a/#{name} b/#{name}\n--- a/#{name}\n+++ b/#{name}\n@@ -1,200 +1,200 @@\n#{changes}"
  end

  def local_request
    stub_request(:post, LOCAL).with do |http|
      yield JSON.parse(http.body) if block_given?
      true
    end.to_return(body: { message: { content: 'fix: handle changes' } }.to_json)
  end
end
