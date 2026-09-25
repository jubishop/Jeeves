# frozen_string_literal: true

require 'jeeves/runtime'
Jeeves::Runtime.check!
require 'jeeves/version'
require 'optparse'

module Jeeves
  class Error < StandardError; end
end

require 'jeeves/settings'
require 'jeeves/diff'
require 'jeeves/prompt'
require 'jeeves/message'
require 'jeeves/providers'
require 'jeeves/git_repository'

module Jeeves
  class CLI
    def initialize(input: $stdin, output: $stdout, errors: $stderr, env: ENV, directory: Dir.pwd)
      @input = input
      @output = output
      @errors = errors
      @env = env
      @git = GitRepository.new(directory)
    end

    def run(arguments = ARGV)
      options = {}
      parser = option_parser(options)
      remaining = arguments.dup
      parser.parse!(remaining)
      raise Error, "Unexpected arguments: #{remaining.join(' ')}" unless remaining.empty?
      return show(parser.to_s) if options[:help]
      return show(VERSION) if options[:version]

      settings = Settings.new(@env, options)
      provider = settings.provider == 'ollama' ? Providers::Ollama.new(settings) : Providers::OpenRouter.new(settings)
      piped = !@input.tty? && !@input.closed?
      if piped
        diff = (@input.read || +'').force_encoding(Encoding::UTF_8)
      else
        raise Error, 'Not inside a Git working tree.' unless @git.root

        @git.stage_all if options[:all] && !options[:dry_run]
        snapshot = @git.snapshot unless options[:dry_run]
        diff = options[:all] && options[:dry_run] ? @git.preview_all : @git.diff
      end
      settings.check_diff!(diff)
      prompt = Prompt.new(home: @env.fetch('HOME') { Dir.home }, repository: @git.root, errors: @errors)
                     .render(diff, settings: settings)
      @errors.puts "Using #{settings.provider}: #{settings.model}" unless piped
      message = Message.prepare(provider.generate(prompt), format: settings.message_format)
      return show(message) if piped || options[:dry_run]

      @output.print @git.commit(message, expected: snapshot)
      @output.print @git.push if options[:push]
      0
    rescue Error, OptionParser::ParseError, IOError, SystemCallError, ArgumentError => e
      @errors.puts "Error: #{e.message}"
      1
    rescue Interrupt
      @errors.puts 'Cancelled.'
      130
    end

    private

    def show(text)
      @output.puts text
      0
    end

    def option_parser(options)
      OptionParser.new do |parser|
        parser.banner = 'Usage: jeeves [options]'
        parser.on('-a', '--all', 'Include all working-tree changes') { options[:all] = true }
        parser.on('-p', '--push', 'Push after a successful commit') { options[:push] = true }
        parser.on('-d', '--dry-run', 'Print the message without staging or committing') { options[:dry_run] = true }
        parser.on('--provider PROVIDER', %w[openrouter ollama], 'Use openrouter or ollama') { |value| options[:provider] = value }
        parser.on('--local', 'Use Ollama for this invocation') { options[:provider] = 'ollama' }
        parser.on('--model MODEL', 'Override the configured model') { |value| options[:model] = value }
        parser.on('--version', 'Show version') { options[:version] = true }
        parser.on('-h', '--help', 'Show help') { options[:help] = true }
      end
    end
  end
end
