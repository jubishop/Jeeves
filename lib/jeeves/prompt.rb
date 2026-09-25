# frozen_string_literal: true

require 'fileutils'

module Jeeves
  class Prompt
    def initialize(home:, repository:, errors:)
      @global_path = File.join(home, '.config', 'jeeves', 'prompt')
      @repository = repository
      @errors = errors
    end

    def render(diff, settings:)
      path = @repository && File.join(@repository, '.jeeves_prompt')
      unless path && File.file?(path)
        path = @global_path
        install unless File.file?(path)
      end
      template = File.read(path, encoding: 'UTF-8')
      raise Error, "Prompt must contain {{DIFF}}: #{path}" unless template.include?('{{DIFF}}')

      limit = settings.max_diff_bytes
      if settings.prompt_budget
        overhead = template.gsub('{{DIFF}}', '').bytesize
        available = (settings.prompt_budget - overhead) / template.scan('{{DIFF}}').length
        if available < 1
          raise Error, 'The prompt leaves no room for a diff. Shorten the prompt or increase GIT_COMMIT_LOCAL_CONTEXT.'
        end
        limit = [limit, available].min
      end
      shortened = Diff.new(diff).fit(limit)
      if shortened != diff
        @errors.puts "Warning: diff shortened from #{diff.bytesize} to #{shortened.bytesize} bytes. " \
                     'Some content is omitted; the commit message may miss changes.'
      end
      template.gsub('{{DIFF}}') { shortened }
    end

    private

    def install
      bundled = File.expand_path('../../config/prompt', __dir__)
      FileUtils.mkdir_p(File.dirname(@global_path))
      # Exclusive creation keeps another first-run invocation's prompt intact.
      File.open(@global_path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
        file.write(File.read(bundled))
      end
      @errors.puts "Installed prompt: #{@global_path}"
    rescue Errno::EEXIST
      nil
    end
  end
end
