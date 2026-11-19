# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'openssl'

module Jeeves
  module Providers
    # A provider's non-200 HTTP response.
    class APIError < Error
      attr_reader :status, :body

      def initialize(status, body, hint = '')
        @status = status
        @body = body
        super("API Error (#{status}): #{body}#{hint}")
      end

      # The provider's own error message, when the body carries one.
      def detail
        message = JSON.parse(body).dig('error', 'message')
        message.is_a?(String) ? message : body
      rescue JSON::ParserError, TypeError, NoMethodError
        body
      end
    end

    class HTTP
      def self.post(uri, body, headers = {}, local: false)
        http = Net::HTTP.new(uri.host, uri.port, local ? nil : :ENV)
        http.open_timeout = 5
        http.read_timeout = local ? 300 : 60
        http.use_ssl = uri.scheme == 'https'
        if http.use_ssl?
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.cert_store = OpenSSL::X509::Store.new.tap(&:set_default_paths)
        end
        request = Net::HTTP::Post.new(uri.request_uri, headers)
        request['Content-Type'] = 'application/json'
        request.body = JSON.generate(body)
        response = http.request(request)
        unless response.code == '200'
          hint = local && response.code == '404' ? " Download the model with: ollama pull #{body[:model]}" : ''
          raise APIError.new(response.code, response.body, hint)
        end
        result = JSON.parse(response.body)
        raise Error, 'Unexpected API response structure' unless result.is_a?(Hash)
        raise Error, "API Error: #{result['error']}" if result['error']

        result
      rescue JSON::ParserError
        raise Error, 'Provider returned invalid JSON'
      rescue IOError, Net::HTTPBadResponse, Net::ProtocolError, OpenSSL::SSL::SSLError => e
        raise Error, "Provider connection failed: #{e.message}"
      end
    end

    class OpenRouter
      def initialize(settings, **)
        @settings = settings
        @key = settings.env['OPENROUTER_API_KEY']
        raise Error, 'OPENROUTER_API_KEY environment variable not set' if @key.nil? || @key.empty?
      end

      def generate(prompt)
        model = @settings.model
        messages = [{ role: 'user', content: prompt }]
        if model.include?('gpt-5') || model.include?('o1')
          messages.unshift(role: 'system', content: 'Respond ONLY with the final commit message. Do not show reasoning.')
        end
        body = { model: model, messages: messages, max_tokens: 1000 }
        body[:stop] = ['END_COMMIT'] unless model.include?('x-ai/')
        headers = { 'Authorization' => "Bearer #{@key}", 'HTTP-Referer' => 'https://github.com/jubishop/Jeeves' }
        result = HTTP.post(URI('https://openrouter.ai/api/v1/chat/completions'), body, headers)
        choice = result.fetch('choices').first
        raise Error, 'OpenRouter reached its output limit; no commit message was accepted' if choice['finish_reason'] == 'length'

        choice.fetch('message').fetch('content')
      rescue KeyError, NoMethodError, TypeError
        raise Error, 'Unexpected OpenRouter response structure'
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => e
        raise Error, "OpenRouter request failed: #{e.message}"
      end
    end

    class Anthropic
      # Errors that refuse the key itself rather than this one request.
      REFUSED_KEY = /credit balance is too low|\b(?:usage|spend|spending) limits?\b/i

      def initialize(settings, errors: $stderr)
        @settings = settings
        @errors = errors
        @key = settings.env['ANTHROPIC_API_KEY']
        raise Error, 'ANTHROPIC_API_KEY environment variable not set' if @key.nil? || @key.empty?
      end

      def generate(prompt)
        request(prompt)
      rescue APIError => e
        raise unless %w[401 403].include?(e.status) || e.body.to_s.match?(REFUSED_KEY)

        fall_back(prompt, "#{e.status}: #{e.detail}")
      end

      private

      def fall_back(prompt, refusal)
        command = ClaudeCommand.new(@settings)
        @errors.puts "Anthropic refused the API key (#{refusal}); falling back to the claude command line with model #{command.model}"
        command.generate(prompt)
      rescue Error => e
        raise Error, "Anthropic refused the API key (#{refusal}), and the claude command line also failed: #{e.message}"
      end

      def request(prompt)
        # Leave thinking at the model's default: newer models reject disabling it.
        # The limit covers thinking as well as the message.
        body = { model: @settings.model, max_tokens: 16_000, messages: [{ role: 'user', content: prompt }] }
        headers = { 'x-api-key' => @key, 'anthropic-version' => '2023-06-01' }
        result = HTTP.post(URI('https://api.anthropic.com/v1/messages'), body, headers)
        raise Error, 'Anthropic reached its output limit; no commit message was accepted' if result['stop_reason'] == 'max_tokens'
        raise Error, 'Anthropic declined to write this commit message' if result['stop_reason'] == 'refusal'

        result.fetch('content').select { |block| block.fetch('type') == 'text' }.map { |block| block.fetch('text') }.join
      rescue KeyError, NoMethodError, TypeError
        raise Error, 'Unexpected Anthropic response structure'
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => e
        raise Error, "Anthropic request failed: #{e.message}"
      end
    end

    class Ollama
      def initialize(settings, **)
        @settings = settings
        host = settings.env.fetch('OLLAMA_HOST', 'http://127.0.0.1:11434')
        host = "http://#{host}" unless host.include?('://')
        @uri = URI.parse(host)
        unless %w[http https].include?(@uri.scheme) && @uri.host && !@uri.userinfo && !@uri.query && !@uri.fragment
          raise Error, 'OLLAMA_HOST must be an HTTP or HTTPS server URL'
        end
        @uri.path = "#{@uri.path.sub(%r{/+\z}, '')}/api/chat"
      rescue URI::InvalidURIError
        raise Error, 'OLLAMA_HOST must be an HTTP or HTTPS server URL'
      end

      def generate(prompt)
        if prompt.bytesize > @settings.prompt_budget
          raise Error, 'Prompt exceeds the conservative local context budget. Split the changes or increase GIT_COMMIT_LOCAL_CONTEXT.'
        end
        body = {
          model: @settings.model, messages: [{ role: 'user', content: prompt }],
          stream: false, think: false,
          options: { num_predict: 1000, num_ctx: @settings.context, stop: ['END_COMMIT'] }
        }
        result = HTTP.post(@uri, body, local: true)
        raise Error, 'Ollama reached its output limit; no commit message was accepted' if result['done_reason'] == 'length'

        result.fetch('message').fetch('content')
      rescue KeyError, NoMethodError, TypeError
        raise Error, 'Unexpected Ollama response structure'
      rescue Errno::ECONNREFUSED, SocketError
        raise Error, 'Cannot connect to Ollama. Start it with ollama serve and check OLLAMA_HOST.'
      rescue Net::OpenTimeout, Net::ReadTimeout
        raise Error, 'Ollama timed out. Check the server or try a smaller model or diff.'
      end
    end

    CLIENTS = { 'openrouter' => OpenRouter, 'anthropic' => Anthropic, 'ollama' => Ollama }.freeze
  end
end
