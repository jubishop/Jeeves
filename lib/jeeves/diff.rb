# frozen_string_literal: true

module Jeeves
  class Diff
    NOTICE = "[Jeeves: diff shortened. Excerpts may omit files, hunks, or parts of lines. " \
             "Hunk ranges are from the original diff; omitted content is unknown.]\n"
    OMITTED = "\n[... content omitted ...]\n"

    def initialize(text)
      @text = text
    end

    def fit(limit)
      return @text if @text.bytesize <= limit

      budget = limit - NOTICE.bytesize
      if budget < OMITTED.bytesize + 8
        raise Error, 'Too little room for a shortened diff. Shorten the prompt or increase ' \
                     'GIT_COMMIT_LOCAL_CONTEXT and GIT_COMMIT_MAX_DIFF_BYTES.'
      end
      compact = without_context
      return NOTICE + compact if compact.bytesize <= budget

      files = compact.split(/(?=^diff --(?:git |cc |combined ))/)
      NOTICE + fit_parts(files, budget) { |file, size| fit_file(file, size) }
    end

    private

    def without_context
      context_prefix = nil
      @text.each_line.reject do |line|
        context_prefix = nil if line.start_with?('diff --')
        match = line.match(/\A(@{2,}) /)
        context_prefix = ' ' * (match[1].length - 1) if match
        context_prefix && line.start_with?(context_prefix)
      end.join
    end

    def fit_file(file, budget)
      return file if file.bytesize <= budget

      header = header_for(file)
      body = file.delete_prefix(header)
      hunks = body.split(/(?=^@@)/)
      header + fit_parts(hunks, budget - header.bytesize) do |hunk, size|
        hunk_header = header_for(hunk)
        hunk_header + excerpt(hunk.delete_prefix(hunk_header), size - hunk_header.bytesize)
      end
    end

    def header_for(part)
      lines = part.lines
      return lines.first.to_s if lines.first&.start_with?('@@')

      lines.take_while { |line| !line.start_with?('@@') }.join
    end

    def fit_parts(parts, budget)
      return parts.join if parts.sum(&:bytesize) <= budget

      # Keep file metadata and hunk headers before sharing space for changes.
      minimums = parts.map { |part| [part.bytesize, header_for(part).bytesize + OMITTED.bytesize + 8].min }
      return excerpt(parts.join, budget) if minimums.sum > budget

      sizes = minimums.dup
      remaining = budget - sizes.sum
      order = parts.each_index.sort_by { |index| parts[index].bytesize - sizes[index] }
      order.each_with_index do |index, position|
        extra = [parts[index].bytesize - sizes[index], remaining / (order.length - position)].min
        sizes[index] += extra
        remaining -= extra
      end
      parts.each_with_index.map { |part, index| yield part, sizes[index] }.join
    end

    def excerpt(text, budget)
      return text if text.bytesize <= budget

      available = budget - OMITTED.bytesize
      head_size = (available + 1) / 2
      tail_size = available / 2
      head = text.byteslice(0, head_size).scrub('')
      tail = text.byteslice(-tail_size, tail_size).scrub('')
      head = head[0..head.rindex("\n")] if head.include?("\n")
      tail = tail[(tail.index("\n") + 1)..] if tail.include?("\n")
      head + OMITTED + tail
    end
  end
end
