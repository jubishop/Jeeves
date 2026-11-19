# frozen_string_literal: true

require 'json'
require 'open3'

module Jeeves
  module Providers
    # Writes a message through the claude command line on the user's Claude
    # subscription, for when the Anthropic API refuses the key.
    class ClaudeCommand
      FAMILIES = %w[haiku sonnet opus fable].freeze
      SYSTEM_PROMPT = 'Respond only with the commit message that the user message asks for.'

      class << self
        attr_accessor :timeout
      end
      self.timeout = 120

      def initialize(settings)
        @settings = settings
      end

      def model
        FAMILIES.find { |family| @settings.model.match?(/\b#{family}\b/) } || @settings.model
      end

      def generate(prompt)
        output, errors, status = run(prompt)
        result = parse(output)
        unless status.success?
          detail = result && result['result'].to_s.strip
          detail = errors.strip if detail.nil? || detail.empty?
          detail = 'no details' if detail.empty?
          raise Error, "claude #{status.exited? ? "exited with status #{status.exitstatus}" : 'stopped'}: #{detail}"
        end
        raise Error, 'claude returned invalid JSON' unless result
        if result['is_error'] != false || result.fetch('subtype', 'success') != 'success'
          raise Error, "claude reported an error: #{result['result'] || result['subtype']}"
        end

        text = result['result']
        raise Error, 'claude returned an empty message' unless text.is_a?(String) && !text.strip.empty?

        text
      end

      private

      def command
        # No --bare: it reads only API keys, never the subscription's login.
        ['claude', '-p', '--model', model, '--tools', '', '--safe-mode', '--strict-mcp-config',
         '--setting-sources', '', '--system-prompt', SYSTEM_PROMPT, '--no-session-persistence',
         '--output-format', 'json']
      end

      def run(prompt)
        # Without the refused key, claude authenticates with the subscription.
        env = @settings.env.to_h.except('ANTHROPIC_API_KEY')
        Open3.popen3(env, *command, unsetenv_others: true, pgroup: true) do |stdin, stdout, stderr, wait|
          threads = [wait, Thread.new { read(stdout) }, Thread.new { read(stderr) }, Thread.new { write(stdin, prompt) }]
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + self.class.timeout
          finished = threads.all? { |thread| thread.join([deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC), 0].max) }
          raise Error, "claude did not finish within #{self.class.timeout} seconds" unless finished

          [threads[1].value, threads[2].value, wait.value]
        ensure
          stop(wait) unless finished
        end
      rescue Errno::ENOENT
        raise Error, 'claude is not installed or not on PATH'
      rescue SystemCallError => e
        raise Error, "claude could not run: #{e.message}"
      end

      def read(io)
        io.read
      rescue IOError
        ''
      end

      def write(stdin, prompt)
        stdin.write(prompt)
      rescue IOError, Errno::EPIPE
        nil
      ensure
        stdin.close
      end

      # Stops claude and anything it started, so nothing outlives the run.
      def stop(wait)
        %w[TERM KILL].each do |signal|
          Process.kill(signal, -wait.pid)
          break if wait.join(2)
        rescue Errno::ESRCH
          break
        end
      end

      def parse(output)
        result = JSON.parse(output)
        result if result.is_a?(Hash)
      rescue JSON::ParserError
        nil
      end
    end
  end
end
