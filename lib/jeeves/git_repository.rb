# frozen_string_literal: true

require 'open3'
require 'tempfile'
require 'tmpdir'
require 'fileutils'

module Jeeves
  class GitRepository
    def initialize(directory = Dir.pwd)
      @directory = directory
    end

    def root
      out, _err, status = capture('rev-parse', '--show-toplevel')
      status.success? ? out.strip : nil
    end

    def stage_all
      run('add', '-A')
    end

    def diff
      run('diff', '--cached', '--no-color', '--no-ext-diff', '--no-textconv')
    end

    def preview_all
      raise Error, 'Not inside a Git working tree.' unless root

      Dir.mktmpdir('jeeves-index-') do |directory|
        index = File.join(directory, 'index')
        current = File.expand_path(run('rev-parse', '--git-path', 'index').strip, @directory)
        FileUtils.cp(current, index) if File.file?(current)
        env = { 'GIT_INDEX_FILE' => index }
        run('read-tree', '--empty', env: env) unless File.file?(index)
        run('add', '-A', env: env)
        run('diff', '--cached', '--no-color', '--no-ext-diff', '--no-textconv', env: env)
      end
    end

    def snapshot
      head, _err, status = capture('rev-parse', '--verify', 'HEAD')
      [run('write-tree').strip, status.success? ? head.strip : nil]
    end

    def commit(message, expected:)
      raise Error, 'HEAD or staged changes changed during generation. Review the index and run Jeeves again.' unless snapshot == expected

      Tempfile.create(['jeeves-commit-', '.txt']) do |file|
        file.write(message)
        file.flush
        run('commit', '-F', file.path)
      end
    end

    def push
      run('push')
    end

    private

    def capture(*args, env: {})
      Open3.capture3(env, 'git', *args, chdir: @directory)
    rescue Errno::ENOENT => e
      raise Error, "Cannot run Git: #{e.message}"
    end

    def run(*args, env: {})
      out, err, status = capture(*args, env: env)
      raise Error, "git #{args.first} failed: #{err.strip}" unless status.success?

      out
    end
  end
end
