require 'jeeves/version'
require 'net/http'
require 'uri'
require 'json'
require 'fileutils'
require 'tmpdir'

module Jeeves
  class CLI
    CONFIG_DIR = File.expand_path('~/.config/jeeves')
    PROMPT_FILE = File.join(CONFIG_DIR, 'prompt')

    def initialize
      @options = {
        all: false,
        push: false
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

        opts.on('-h', '--help', 'Show this help message') do
          puts opts
          exit
        end
      end.parse!
    end

    def run
      parse_options
      
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
          puts "Copying bundled prompt file to #{PROMPT_FILE}"
          FileUtils.cp(config_prompt, PROMPT_FILE)
          puts "Prompt file installed successfully."
        else
          puts "Error: Prompt file not found at #{PROMPT_FILE}"
          puts "No bundled prompt file found at: #{config_prompt}"
          puts "Please create a prompt file with your custom prompt."
          exit 1 unless defined?(TESTING_MODE) && TESTING_MODE
        end
      end
    end

    def generate_commit_message(diff)
      api_key = ENV['OPENROUTER_API_KEY']
      if api_key.nil? || api_key.empty?
        puts "Error: OPENROUTER_API_KEY environment variable not set"
        exit 1
      end

      model = ENV['GIT_COMMIT_MODEL'] || 'openai/gpt-5-mini'
      
      prompt_file_path = get_prompt_file_path
      puts "Using prompt file: #{prompt_file_path}"
      prompt = File.read(prompt_file_path).gsub('{{DIFF}}', diff)
      
      uri = URI.parse('https://openrouter.ai/api/v1/chat/completions')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri.request_uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{api_key}"
      request['HTTP-Referer'] = 'https://github.com/jeeves-git-commit'
      
      # For reasoning models, use system message to enforce output format
      messages = if model.include?('gpt-5') || model.include?('o1')
        [
          { role: 'system', content: 'You are a git commit message generator. Respond ONLY with the final commit message. Do not show your thinking or reasoning process.' },
          { role: 'user', content: prompt }
        ]
      else
        [
          { role: 'user', content: prompt }
        ]
      end
      
      request_body = {
        model: model,
        messages: messages,
        max_tokens: 500
      }
      
      # For reasoning models, try to exclude reasoning from output
      if model.include?('gpt-5') || model.include?('o1')
        request_body[:reasoning] = { exclude: true }
      end
      
      request.body = request_body.to_json
      
      begin
        response = http.request(request)
        
        if response.code == '200'
          result = JSON.parse(response.body)
          
          # Better error handling for API response structure
          if result['choices'] && result['choices'][0] && result['choices'][0]['message']
            message = result['choices'][0]['message']
            commit_message = message['content']
            
            # Handle OpenAI reasoning models (like GPT-5 mini) where content might be empty
            # but reasoning contains the actual response
            if (!commit_message || commit_message.strip.empty?) && message['reasoning']
              commit_message = message['reasoning']
            end
            
            if commit_message && !commit_message.strip.empty?
              commit_message = commit_message.strip
              puts "Generated commit message:"
              puts "------------------------"
              puts commit_message
              puts "------------------------"
              return commit_message
            else
              puts "Error: API returned empty commit message"
              puts "Full API response: #{response.body}"
              exit 1
            end
          else
            puts "Error: Unexpected API response structure"
            puts "Full API response: #{response.body}"
            exit 1
          end
        else
          puts "API Error (#{response.code}): #{response.body}"
          exit 1
        end
      rescue => e
        puts "Error: #{e.message}"
        exit 1
      end
    end
  end
end
