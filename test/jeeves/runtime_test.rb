require 'test_helper'

class RuntimeTest < Minitest::Test
  ROOT = File.expand_path('../..', __dir__)

  def test_accepts_the_minimum_and_newer_rubies
    %w[3.3.0 4.0.7 4.1.0 5.0.0].each do |version|
      assert_nil Jeeves::Runtime.check!(version), version
    end
  end

  def test_rejects_rubies_below_the_minimum_with_guidance
    _output, errors = capture_io do
      assert_raises(SystemExit) { Jeeves::Runtime.check!('3.2.9') }
    end
    assert_includes errors, 'Jeeves requires Ruby >= 3.3; found 3.2.9.'
  end

  def test_gemspec_declares_the_runtime_requirement
    specification = Dir.chdir(ROOT) { Gem::Specification.load('jeeves.gemspec') }
    assert_equal Jeeves::Runtime::REQUIREMENT.to_s, specification.required_ruby_version.to_s
  end
end
