# frozen_string_literal: true

module Jeeves
  class Message
    EMOJI = { 'feat' => '✨', 'fix' => '🐛', 'refactor' => '♻️', 'perf' => '⚡',
              'docs' => '📝', 'test' => '✅', 'build' => '🔧', 'ci' => '🔧',
              'chore' => '🔧', 'style' => '🎨', 'revert' => '⏪' }.freeze
    SUBJECT = /\A(?<type>feat|fix|refactor|perf|docs|test|build|ci|chore|style|revert)(?<rest>(?:\([^\r\n()]+\))?!?: \S[^\r\n]*)\z/.freeze

    def self.prepare(content, format:)
      raise Error, 'Provider returned an empty or invalid commit message' unless content.is_a?(String) && !content.strip.empty?

      content = content.strip
      if content.match?(/<\/?(?:think|analysis|reasoning)>|\A```|\A(?:commit message|analysis|reasoning):/i) || content.match?(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/)
        raise Error, 'Provider returned reasoning, markup, or control characters instead of a commit message'
      end
      return content if format == 'plain'

      subject, body = content.split("\n", 2)
      # Normalize the decoration locally; another model call would add latency.
      subject = subject.sub(/\A[\p{So}\p{Sk}\uFE0F\u200D]+\s*/, '')
      match = SUBJECT.match(subject)
      unless match
        raise Error, 'Invalid commit subject. Expected type(scope): description. Use GIT_COMMIT_MESSAGE_FORMAT=plain for custom formats.'
      end

      ["#{EMOJI.fetch(match[:type])} #{subject}", body&.strip].compact.join("\n\n")
    end
  end
end
