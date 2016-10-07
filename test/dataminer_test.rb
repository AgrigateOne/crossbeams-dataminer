require 'test_helper'

class Crossbeams::DataminerTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Crossbeams::Dataminer::VERSION
  end

end
