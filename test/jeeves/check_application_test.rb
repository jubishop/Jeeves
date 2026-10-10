require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'rbconfig'

# Verifies the application checks that bin/check --full runs, with a simulated Bundler.
class CheckApplicationTest < Minitest::Test
  ROOT = File.expand_path('../..', __dir__)

  def setup
    @workspace = Dir.mktmpdir('jeeves-check-application-')
    @repo = File.join(@workspace, 'checkout')
    FileUtils.mkdir_p(File.join(@repo, 'bin'))
    FileUtils.cp(File.join(ROOT, 'bin/check-application'), File.join(@repo, 'bin/check-application'), preserve: true)
    @tools = File.join(@workspace, 'tools')
    FileUtils.mkdir_p(@tools)
    python = ENV.fetch('PATH').split(File::PATH_SEPARATOR).map { |directory| File.join(directory, 'python3') }
                .find { |path| File.executable?(path) }
    File.symlink(python, File.join(@tools, 'python3'))
    @bundle = File.join(@tools, 'bundle')
    File.write(@bundle, <<~RUBY)
      #!#{RbConfig.ruby}
      File.write(ENV.fetch('CHECK_EVENTS'), "\#{Dir.pwd} \#{ARGV.join(' ')}")
      exit Integer(ENV.fetch('APP_EXIT', '0'))
    RUBY
    File.chmod(0o755, @bundle)
    @events = File.join(@workspace, 'events')
    @env = { 'PATH' => @tools, 'CHECK_EVENTS' => @events, 'APP_EXIT' => nil }
  end

  def teardown
    FileUtils.remove_entry(@workspace)
  end

  def check(extra = {})
    # Start outside the checkout to prove the script runs from its own root.
    Open3.capture3(@env.merge(extra), File.join(@repo, 'bin/check-application'), chdir: @workspace)
  end

  def test_runs_rake_validate_through_bundler_from_the_root
    _output, errors, status = check
    assert status.success?, errors
    assert_equal "#{File.realpath(@repo)} exec rake validate", File.read(@events)
  end

  def test_validation_failure_status_propagates
    _output, _errors, status = check('APP_EXIT' => '17')
    assert_equal 17, status.exitstatus
  end

  def test_missing_bundler_fails_with_a_message
    File.delete(@bundle)
    _output, errors, status = check
    assert_equal 1, status.exitstatus
    assert_includes errors, 'bundle'
    refute File.exist?(@events)
  end
end
