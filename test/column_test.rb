require 'test_helper'

class ColumnTest < Minitest::Test

  def test_column_caption
    column = Dataminer::Column.new(1, {"name"=>nil, "indirection"=>nil, "val"=>{"COLUMNREF"=>{"fields"=>["b", "name"], "location"=>12}}})
    assert_equal 'Name', column.caption
  end

  def test_column_namespace_name_no_alias
    column = Dataminer::Column.new(1, {"name"=>nil, "indirection"=>nil, "val"=>{"COLUMNREF"=>{"fields"=>["name"], "location"=>12}}})
    assert_equal 'name', column.namespaced_name
  end

  def test_column_namespace_name
    column = Dataminer::Column.new(1, {"name"=>nil, "indirection"=>nil, "val"=>{"COLUMNREF"=>{"fields"=>["b", "name"], "location"=>12}}})
    assert_equal 'b.name', column.namespaced_name
  end

end

