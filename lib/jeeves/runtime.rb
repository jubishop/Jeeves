# frozen_string_literal: true

require 'rubygems/requirement'

module Jeeves
  module Runtime
    REQUIREMENT = Gem::Requirement.new('>= 3.3', '< 4.1').freeze

    def self.check!
      return if REQUIREMENT.satisfied_by?(Gem::Version.new(RUBY_VERSION))

      abort "Jeeves requires Ruby #{REQUIREMENT}; found #{RUBY_VERSION}. Select a supported Ruby with your version manager."
    end
  end
end
