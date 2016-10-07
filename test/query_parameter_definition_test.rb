require 'test_helper'

class QueryParameterDefinitionTest < Minitest::Test

  def test_defaults
    param = Crossbeams::Dataminer::QueryParameterDefinition.new('col')
    assert_equal 'col', param.caption
    assert_equal :string, param.data_type
    assert_equal :text, param.control_type
    assert_equal 1, param.ui_priority
  end

  def test_caption
    param = Crossbeams::Dataminer::QueryParameterDefinition.new('col', caption: 'Other')
    assert_equal 'Other', param.caption
    assert_equal :string, param.data_type
    assert_equal :text, param.control_type
    assert_equal 1, param.ui_priority
  end

  def test_ordered_sql_list
    param = Crossbeams::Dataminer::QueryParameterDefinition.new('col', :control_type => :list, :list_def => 'SELECT code FROM table ORDER BY code')
    assert param.list_is_ordered?
  end

  def test_unordered_sql_list
    param = Crossbeams::Dataminer::QueryParameterDefinition.new('col', :control_type => :list, :list_def => 'SELECT code FROM table')
    refute param.list_is_ordered?
  end

  def test_build_array_list
    param = Crossbeams::Dataminer::QueryParameterDefinition.new('col', :control_type => :list, :list_def => [1,2,3])
    assert_equal [1,2,3], param.build_list.list_values
    assert_equal [1,2,3], param.build_list {|sql| ['a','b'] }.list_values
  end

  def test_build_hash_list
    param = Crossbeams::Dataminer::QueryParameterDefinition.new('col', :control_type => :list, :list_def => {'a' => 1, 'b' => 2, 'c' => 3})
    assert_equal [['a',1],['b',2],['c',3]], param.build_list.list_values
  end

  def test_build_list_from_block
    param = Crossbeams::Dataminer::QueryParameterDefinition.new('col', :control_type => :list, :list_def => 'SELECT code FROM table ORDER BY code')
    assert_equal [['a',1],['b',2],['c',3]], param.build_list {|sql| {'a' => 1, 'b' => 2, 'c' => 3} }.list_values
  end

end
