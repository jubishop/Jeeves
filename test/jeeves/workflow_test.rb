require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'socket'
require 'json'
require 'rbconfig'

class WorkflowTest < Minitest::Test
  ROOT = File.expand_path('../..', __dir__)

  def setup
    @workspace = Dir.mktmpdir('jeeves-workflow-')
    @repo = File.join(@workspace, 'repo')
    FileUtils.mkdir_p(@repo)
    @env = {
      'HOME' => File.join(@workspace, 'home'),
      'TMPDIR' => File.join(@workspace, 'temporary files'),
      'GIT_CONFIG_GLOBAL' => File::NULL, 'GIT_CONFIG_NOSYSTEM' => '1',
      'GIT_COMMIT_PROVIDER' => 'ollama', 'GIT_COMMIT_LOCAL_MODEL' => 'test-model',
      'GIT_COMMIT_LOCAL_CONTEXT' => '32768', 'OPENROUTER_API_KEY' => nil,
      'GIT_COMMIT_MAX_DIFF_BYTES' => nil, 'GIT_COMMIT_MESSAGE_FORMAT' => nil
    }
    FileUtils.mkdir_p([@env['HOME'], @env['TMPDIR']])
    git('init', '-q')
    git('config', 'user.email', 'test@example.com')
    git('config', 'user.name', 'Test User')
    File.write(File.join(@repo, 'file.txt'), "old\n")
    git('add', '.')
    git('commit', '-qm', 'initial')
    @original_head = git('rev-parse', 'HEAD').strip
    @tty = File.join(@workspace, 'tty.rb')
    File.write(@tty, 'STDIN.define_singleton_method(:tty?) { true }')
    @requests = []
    @response = { message: { content: "🐛 fix: correct retry handling\n\nKeep retries for rate limits and server errors." }, done_reason: 'stop' }
    @server = TCPServer.new('127.0.0.1', 0)
    @env['OLLAMA_HOST'] = "http://127.0.0.1:#{@server.addr[1]}"
    @worker = Thread.new do
      loop do
        socket = @server.accept
        begin
          socket.gets
          headers = {}
          while (line = socket.gets) && line != "\r\n"
            key, value = line.split(':', 2)
            headers[key.downcase] = value.strip
          end
          @requests << JSON.parse(socket.read(headers.fetch('content-length').to_i))
          @on_request.call if @on_request
          body = JSON.generate(@response)
          socket.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
        ensure
          socket.close
        end
      end
    rescue IOError, Errno::EBADF
      nil
    end
  end

  def teardown
    @server&.close
    @worker&.join(2)
    @worker&.kill
    FileUtils.remove_entry(@workspace)
  end

  def test_failed_staging_stops_before_generation
    stage_change
    File.write(File.join(@repo, '.git/index.lock'), '')
    _out, _err, status = run_cli('--all')
    refute status.success?
    assert_empty @requests
    assert_equal @original_head, git('rev-parse', 'HEAD').strip
  end

  def test_failed_commit_does_not_push_and_returns_failure
    stage_change
    hook('pre-commit', "exit 1\n")
    hook('pre-push', "touch '#{@workspace}/pushed'\n")
    bare = File.join(@workspace, 'remote.git')
    git('init', '--bare', '-q', bare)
    git('remote', 'add', 'origin', bare)
    git('config', 'push.default', 'current')
    _out, _err, status = run_cli('--push')
    refute status.success?
    refute File.exist?(File.join(@workspace, 'pushed'))
    assert_equal @original_head, git('rev-parse', 'HEAD').strip
  end

  def test_all_dry_run_preserves_index_and_head
    File.write(File.join(@repo, 'file.txt'), "new\n")
    File.write(File.join(@repo, 'new.txt'), "untracked\n")
    index = File.binread(File.join(@repo, '.git/index'))
    out, err, status = run_cli('--all', '--dry-run')
    assert status.success?, err
    assert_includes out, 'correct retry handling'
    assert_equal index, File.binread(File.join(@repo, '.git/index'))
    assert_equal @original_head, git('rev-parse', 'HEAD').strip
    assert_includes @requests.first.dig('messages', -1, 'content'), '+untracked'
  end

  def test_commit_handles_spaces_in_temporary_directory_and_cleans_up
    stage_change
    _out, err, status = run_cli
    assert status.success?, err
    refute_equal @original_head, git('rev-parse', 'HEAD').strip
    assert_includes git('log', '-1', '--format=%B'), 'correct retry handling'
    assert_empty Dir.children(@env['TMPDIR'])
  end

  def test_diff_backslashes_reach_the_provider_unchanged
    diff = "+replacement = '\\1'; whole = '\\&'\n"
    _out, err, status = run_cli(stdin: diff)
    assert status.success?, err
    assert_includes @requests.last.dig('messages', -1, 'content'), diff
  end

  def test_changed_index_during_generation_is_not_committed
    stage_change
    @on_request = -> { File.write(File.join(@repo, 'unseen.txt'), 'unseen'); git('add', 'unseen.txt') }
    _out, err, status = run_cli
    refute status.success?
    assert_match(/staged|index/i, err)
    assert_equal @original_head, git('rev-parse', 'HEAD').strip
  end

  def test_oversized_diff_is_rejected_before_network_request
    @env['GIT_COMMIT_MAX_DIFF_BYTES'] = '100'
    _out, err, status = run_cli(stdin: 'x' * 101)
    refute status.success?
    assert_match(/large|limit|bytes/i, err)
    assert_empty @requests
  end

  def test_reasoning_and_malformed_output_are_not_committed
    stage_change
    @response[:message][:content] = '<think>Let me reason</think> fix: something'
    _out, _err, status = run_cli
    refute status.success?
    assert_equal @original_head, git('rev-parse', 'HEAD').strip
  end

  def test_missing_emoji_is_added_without_another_generation
    @response[:message][:content] = "fix(client): correct retry handling\n\nKeep retries for rate limits."
    out, err, status = run_cli(stdin: '+test')
    assert status.success?, err
    assert out.start_with?('🐛 fix(client):'), out
    assert_equal 1, @requests.length
  end

  def test_help_does_not_create_configuration
    _out, err, status = run_cli('--help')
    assert status.success?, err
    refute Dir.exist?(File.join(@env['HOME'], '.config/jeeves'))
    assert_empty @requests
  end

  def test_repository_prompt_takes_precedence_without_installing_global_prompt
    File.write(File.join(@repo, '.jeeves_prompt'), 'Repository instructions {{DIFF}}')
    _out, err, status = run_cli(stdin: '+test')
    assert status.success?, err
    assert_equal 'Repository instructions +test', @requests.first.dig('messages', -1, 'content')
    refute File.exist?(File.join(@env['HOME'], '.config/jeeves/prompt'))
  end

  def test_first_run_installs_bundled_prompt_and_keeps_stdout_clean
    out, err, status = run_cli(stdin: '+test')
    assert status.success?, err
    assert out.start_with?('🐛 fix:'), out
    assert_includes err, 'Installed prompt:'
    path = File.join(@env['HOME'], '.config/jeeves/prompt')
    assert_equal File.read(File.join(ROOT, 'config/prompt')), File.read(path)
    File.write(path, 'Personal instructions {{DIFF}}')
    _out, err, status = run_cli(stdin: '+second')
    assert status.success?, err
    assert_equal 'Personal instructions +second', @requests.last.dig('messages', -1, 'content')
  end

  def test_initial_commit_and_dry_run_in_unborn_repository
    other = File.join(@workspace, 'unborn')
    FileUtils.mkdir_p(other)
    @repo = other
    git('init', '-q')
    git('config', 'user.email', 'test@example.com')
    git('config', 'user.name', 'Test User')
    File.write(File.join(@repo, 'first.txt'), 'first')
    _out, err, status = run_cli('--all', '--dry-run')
    assert status.success?, err
    refute File.exist?(File.join(@repo, '.git/index'))
    _out, err, status = run_cli('--all')
    assert status.success?, err
    assert_includes git('show', 'HEAD:first.txt'), 'first'
  end

  def test_push_failure_is_reported_after_successful_commit
    stage_change
    _out, err, status = run_cli('--push')
    refute status.success?
    assert_includes err, 'git push failed'
    refute_equal @original_head, git('rev-parse', 'HEAD').strip
    assert_empty Dir.children(@env['TMPDIR'])
  end

  def test_successful_commit_is_pushed_to_local_remote
    stage_change
    remote = File.join(@workspace, 'remote.git')
    git('init', '--bare', '-q', remote)
    git('remote', 'add', 'origin', remote)
    git('config', 'push.default', 'current')
    _out, err, status = run_cli('--push')
    assert status.success?, err
    branch = git('branch', '--show-current').strip
    assert_equal git('rev-parse', 'HEAD').strip, git('--git-dir', remote, 'rev-parse', "refs/heads/#{branch}").strip
  end

  def test_unsupported_ruby_stops_before_configuration_or_network
    File.write(@tty, "Object.send(:remove_const, :RUBY_VERSION)\nRUBY_VERSION = '3.2.0'\n")
    _out, err, status = run_cli('--version')
    refute status.success?
    assert_includes err, 'Jeeves requires Ruby'
    refute Dir.exist?(File.join(@env['HOME'], '.config/jeeves'))
    assert_empty @requests
  end

  private

  def git(*args)
    out, err, status = Open3.capture3(@env, 'git', *args, chdir: @repo)
    raise err unless status.success?
    out
  end

  def stage_change
    File.write(File.join(@repo, 'file.txt'), "new\n")
    git('add', 'file.txt')
  end

  def hook(name, body)
    path = File.join(@repo, '.git/hooks', name)
    File.write(path, "#!/bin/sh\n#{body}")
    File.chmod(0o755, path)
  end

  def run_cli(*args, stdin: nil)
    command = [RbConfig.ruby]
    command += ['-r', @tty] if stdin.nil?
    Open3.capture3(@env, *command, File.join(ROOT, 'bin/jeeves'), *args,
                   chdir: @repo, stdin_data: stdin || '')
  end
end
