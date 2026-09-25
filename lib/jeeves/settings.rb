# frozen_string_literal: true

module Jeeves
  class Settings
    attr_reader :provider, :model, :context, :max_diff_bytes, :message_format, :env

    def initialize(env, options = {})
      @env = env
      @provider = options[:provider] || env.fetch('GIT_COMMIT_PROVIDER', 'openrouter')
      raise Error, 'GIT_COMMIT_PROVIDER must be openrouter or ollama' unless %w[openrouter ollama].include?(@provider)

      @model = options[:model] || if @provider == 'ollama'
                                    env.fetch('GIT_COMMIT_LOCAL_MODEL', 'gemma4:26b')
                                  else
                                    env.fetch('GIT_COMMIT_MODEL', 'x-ai/grok-code-fast-1')
                                  end
      raise Error, 'The configured model must not be empty' if @model.strip.empty?

      @context = integer('GIT_COMMIT_LOCAL_CONTEXT', 65_536) if @provider == 'ollama'
      @max_diff_bytes = integer('GIT_COMMIT_MAX_DIFF_BYTES', 65_536)
      @message_format = env.fetch('GIT_COMMIT_MESSAGE_FORMAT', 'conventional')
      return if %w[conventional plain].include?(@message_format)

      raise Error, 'GIT_COMMIT_MESSAGE_FORMAT must be conventional or plain'
    end

    def check_diff!(diff)
      raise Error, 'Diff must be valid UTF-8 text.' unless diff.valid_encoding?
      raise Error, 'No diff content provided.' if diff.strip.empty?
    end

    def prompt_budget
      # One byte per token, with room for output and chat framing.
      context - 1000 - 256 if context
    end

    private

    def integer(name, default)
      value = Integer(env.fetch(name, default.to_s), 10)
      raise ArgumentError unless value.positive?

      value
    rescue ArgumentError
      raise Error, "#{name} must be a positive integer"
    end
  end
end
