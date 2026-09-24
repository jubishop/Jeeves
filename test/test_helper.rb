# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'stringio'
require 'minitest/autorun'
require 'webmock/minitest'
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'jeeves'

WebMock.disable_net_connect!

class Minitest::Test
  def with_cli_environment
    Dir.mktmpdir('jeeves-cli-') do |directory|
      env = {
        'HOME' => directory, 'GIT_COMMIT_PROVIDER' => 'ollama',
        'GIT_COMMIT_LOCAL_MODEL' => 'local-model', 'GIT_COMMIT_MODEL' => 'cloud-model',
        'OPENROUTER_API_KEY' => 'test-key'
      }
      path = File.join(directory, '.config/jeeves/prompt')
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, 'Describe {{DIFF}}')
      yield env, directory
    end
  end

  def invoke(env, directory, args: [], diff: 'test diff')
    output = StringIO.new
    errors = StringIO.new
    cli = Jeeves::CLI.new(input: StringIO.new(diff), output: output, errors: errors,
                         env: env, directory: directory)
    [cli.run(args), output.string, errors.string]
  end
end
