require 'test_helper'

class DataminerTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Dataminer::VERSION
  end

end
