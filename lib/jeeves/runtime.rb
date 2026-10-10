# frozen_string_literal: true

require 'rubygems/requirement'

module Jeeves
  module Runtime
    REQUIREMENT = Gem::Requirement.new('>= 3.3').freeze

    def self.check!(version = RUBY_VERSION)
      return if REQUIREMENT.satisfied_by?(Gem::Version.new(version))

      abort "Jeeves requires Ruby #{REQUIREMENT}; found #{version}. Select the latest stable Ruby with your version manager."
    end
  end
end
