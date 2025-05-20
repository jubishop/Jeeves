require 'test_helper'

class VersionTest < Minitest::Test
  def test_version_exists
    refute_nil ::Jeeves::VERSION
  end
  
  def test_version_is_string
    assert_kind_of String, ::Jeeves::VERSION
  end
end
