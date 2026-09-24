require 'jeeves/version'
require 'net/http'
require 'uri'
require 'json'
require 'fileutils'
require 'tmpdir'
require 'openssl'

module Jeeves
  class CLI
    CONFIG_DIR = File.expand_path('~/.config/jeeves')
    PROMPT_FILE = File.join(CONFIG_DIR, 'prompt')

    def initialize
      @options = {
        all: false,
        push: false,
        dry_run: false
      }
      setup_config_dir
    end

    def parse_options
      require 'optparse'
      
      OptionParser.new do |opts|
        opts.banner = 'Usage: jeeves [options]'
        opts.version = VERSION

        opts.on('-a', '--all', 'Stage all changes before committing') do
          @options[:all] = true
        end

        opts.on('-p', '--push', 'Push changes after committing') do
          @options[:push] = true
        end

        opts.on('-d', '--dry-run', 'Generate commit message without committing') do
          @options[:dry_run] = true
        end

        opts.on('--provider PROVIDER', %w[openrouter ollama], 'Use openrouter or ollama') do |provider|
          @options[:provider] = provider
        end

        opts.on('--local', 'Use Ollama for this invocation') do
          @options[:provider] = 'ollama'
        end

        opts.on('--model MODEL', 'Override the configured model for this invocation') do |model|
          @options[:model] = model
        end

        opts.on('-h', '--help', 'Show this help message') do
          puts opts
          exit
        end
      end.parse!
    end

    def run
      parse_options
      
      # Automatically detect stdin input
      has_stdin_input = !STDIN.tty? || STDIN.closed?
      
      # Handle stdin mode when auto-detected
      if has_stdin_input
        # Read diff from stdin
        diff = STDIN.read
        
        if diff.empty?
          puts "Error: No diff content provided via stdin."
          exit 1
        end
        
        # Generate commit message and output just the message
        commit_message = generate_commit_message(diff, suppress_output: true)
        puts commit_message
        return
      end
      
      # Normal mode: work with git staged changes
      if @options[:all]
        system('git add -A')
      end

      # Get git diff of staged changes
      diff = `git diff --staged`
      
      if diff.empty?
        puts "No changes staged for commit."
        exit 1
      end

      # Get AI-generated commit message
      commit_message = generate_commit_message(diff)
      
      # If dry-run mode, just output the message and exit
      if @options[:dry_run]
        puts "\nDry-run mode: Commit message would be:"
        puts "============================================"
        puts commit_message
        puts "============================================"
        puts "No commit was created (dry-run mode)"
        return
      end
      
      # Write commit message to temp file for git to use
      temp_file = File.join(Dir.tmpdir, 'jeeves_commit_message')
      File.write(temp_file, commit_message)
      
      # Commit with the generated message
      system("git commit -F #{temp_file}")
      
      # Clean up temp file
      File.unlink(temp_file) if File.exist?(temp_file)
      
      # Push if requested
      if @options[:push]
        puts "Pushing changes..."
        system('git push')
      end
    end

    private

    def git_root_dir
      output = `git rev-parse --show-toplevel 2>/dev/null`.strip
      output.empty? ? nil : output
    end

    def get_prompt_file_path
      git_root = git_root_dir
      if git_root
        local_prompt = File.join(git_root, '.jeeves_prompt')
        return local_prompt if File.exist?(local_prompt)
      end
      PROMPT_FILE
    end

    def setup_config_dir
      unless Dir.exist?(CONFIG_DIR)
        FileUtils.mkdir_p(CONFIG_DIR)
      end

      unless File.exist?(PROMPT_FILE)
        # Check for bundled prompt file in the config directory
        config_prompt = File.join(File.dirname(__FILE__), '..', 'config', 'prompt')
        
        if File.exist?(config_prompt)
          warn "Copying bundled prompt file to #{PROMPT_FILE}"
          FileUtils.cp(config_prompt, PROMPT_FILE)
          warn 'Prompt file installed successfully.'
        else
          puts "Error: Prompt file not found at #{PROMPT_FILE}"
          puts "No bundled prompt file found at: #{config_prompt}"
          puts "Please create a prompt file with your custom prompt."
          exit 1 unless defined?(TESTING_MODE) && TESTING_MODE
        end
      end
    end

    def generate_commit_message(diff, suppress_output: false)
      provider = @options[:provider] || ENV.fetch('GIT_COMMIT_PROVIDER', 'openrouter')
      unless %w[openrouter ollama].include?(provider)
        raise ArgumentError, 'GIT_COMMIT_PROVIDER must be openrouter or ollama'
      end

      model = @options[:model] || configured_model(provider)
      raise ArgumentError, 'The configured model must not be empty' if model.strip.empty?

      puts "Using provider: #{provider}" unless suppress_output
      puts "Using model: #{model}" unless suppress_output
      prompt_file_path = get_prompt_file_path
      puts "Using prompt file: #{prompt_file_path}" unless suppress_output
      prompt = File.read(prompt_file_path).gsub('{{DIFF}}', diff)

      message = if provider == 'ollama'
                  generate_with_ollama(model, prompt)
                else
                  generate_with_openrouter(model, prompt)
                end
      unless message.is_a?(String) && !message.strip.empty?
        raise ArgumentError, "#{provider} returned an empty or invalid commit message for #{model}"
      end

      message = message.strip
      unless suppress_output
        puts 'Generated commit message:'
        puts '------------------------'
        puts message
        puts '------------------------'
      end
      message
    rescue StandardError => e
      warn "Error: #{e.message}"
      exit 1
    end

    def configured_model(provider)
      if provider == 'ollama'
        ENV.fetch('GIT_COMMIT_LOCAL_MODEL', 'qwen3.8:27b')
      else
        ENV.fetch('GIT_COMMIT_MODEL', 'x-ai/grok-code-fast-1')
      end
    end

    def generate_with_openrouter(model, prompt)
      api_key = ENV['OPENROUTER_API_KEY']
      if api_key.nil? || api_key.empty?
        raise ArgumentError, 'OPENROUTER_API_KEY environment variable not set'
      end

      messages = [{ role: 'user', content: prompt }]
      if model.include?('gpt-5') || model.include?('o1')
        messages.unshift(
          role: 'system',
          content: 'You are a git commit message generator. Respond ONLY with the final commit message. ' \
                   'Do not show your thinking or reasoning process.'
        )
      end
      body = { model: model, messages: messages, max_tokens: 1000 }
      body[:stop] = ['END_COMMIT'] unless model.include?('x-ai/')
      headers = {
        'Authorization' => "Bearer #{api_key}",
        'HTTP-Referer' => 'https://github.com/jeeves-git-commit'
      }
      result = request_completion(URI('https://openrouter.ai/api/v1/chat/completions'), body, headers)
      choice = result.fetch('choices').first
      if choice['finish_reason'] == 'length'
        raise ArgumentError, 'OpenRouter reached its output limit; no commit message was accepted'
      end

      choice.fetch('message').fetch('content')
    end

    def generate_with_ollama(model, prompt)
      host = ENV.fetch('OLLAMA_HOST', 'http://127.0.0.1:11434')
      host = "http://#{host}" unless host.include?('://')
      uri = URI.parse(host)
      unless %w[http https].include?(uri.scheme) && uri.host && !uri.userinfo && !uri.query && !uri.fragment
        raise ArgumentError, 'OLLAMA_HOST must be an HTTP or HTTPS server URL'
      end

      uri.path = "#{uri.path.sub(%r{/+\z}, '')}/api/chat"
      context = Integer(ENV.fetch('GIT_COMMIT_LOCAL_CONTEXT', '32768'), 10)
      raise ArgumentError, 'GIT_COMMIT_LOCAL_CONTEXT must be a positive integer' unless context.positive?

      body = {
        model: model,
        messages: [{ role: 'user', content: prompt }],
        stream: false,
        think: false,
        options: { num_predict: 1000, num_ctx: context, stop: ['END_COMMIT'] }
      }
      result = request_completion(uri, body, {}, local: true)
      if result['done_reason'] == 'length'
        raise ArgumentError, 'Ollama reached its output limit; no commit message was accepted'
      end

      result.fetch('message').fetch('content')
    rescue Errno::ECONNREFUSED, SocketError
      raise IOError, 'Cannot connect to Ollama. Start it with ollama serve and check OLLAMA_HOST.'
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise IOError, 'Ollama timed out. Check the server or try a smaller model or diff.'
    end

    def request_completion(uri, body, headers, local: false)
      http = Net::HTTP.new(uri.host, uri.port, local ? nil : :ENV)
      http.open_timeout = 5
      http.read_timeout = local ? 300 : 60
      http.use_ssl = uri.scheme == 'https'
      if http.use_ssl?
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        store = OpenSSL::X509::Store.new
        store.set_default_paths
        http.cert_store = store
      end

      request = Net::HTTP::Post.new(uri.request_uri, headers)
      request['Content-Type'] = 'application/json'
      request.body = body.to_json
      response = http.request(request)
      unless response.code == '200'
        hint = local && response.code == '404' ? " Download the model with: ollama pull #{body[:model]}" : ''
        raise IOError, "API Error (#{response.code}): #{response.body}#{hint}"
      end
      result = JSON.parse(response.body)
      raise ArgumentError, 'Unexpected API response structure' unless result.is_a?(Hash)
      raise IOError, "API Error: #{result['error']}" if result['error']

      result
    end
  end
end
