require 'test_helper'

class QueryParameterTest < Minitest::Test

  def test_with_datatype
    opval1 = Crossbeams::Dataminer::OperatorValue.new('=', [123], :integer)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "col = 123", param.to_string
  end

  def test_null
    opval1 = Crossbeams::Dataminer::OperatorValue.new('is_null', 123, :integer)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "col IS NULL", param.to_string
  end

  def test_null_to_text
    opval1 = Crossbeams::Dataminer::OperatorValue.new('is_null', 123, :integer)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "col is blank", param.to_text
  end

  def test_not_null
    opval1 = Crossbeams::Dataminer::OperatorValue.new('not_null', 123, :integer)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "col IS NOT NULL", param.to_string
  end

  def test_not_null_to_text
    opval1 = Crossbeams::Dataminer::OperatorValue.new('not_null', 123, :integer)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "col is not blank", param.to_text
  end

  def test_boolean
    opval1 = Crossbeams::Dataminer::OperatorValue.new('=', true, :boolean)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "col = 't'", param.to_string
  end

  def test_boolean_to_text
    opval1 = Crossbeams::Dataminer::OperatorValue.new('=', true, :boolean)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "is col", param.to_text
  end

  def test_match_or_null
    opval1 = Crossbeams::Dataminer::OperatorValue.new('match_or_null', 1, :integer)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "(col = 1 OR col IS NULL)", param.to_string
  end

  def test_match_or_null_to_text
    opval1 = Crossbeams::Dataminer::OperatorValue.new('match_or_null', 1, :integer)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "col is 1 or blank", param.to_text
  end

  def test_match_or_null_str
    opval1 = Crossbeams::Dataminer::OperatorValue.new('match_or_null', 'AAA')
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "(col = 'AAA' OR col IS NULL)", param.to_string
  end

  def test_in
    opval1 = Crossbeams::Dataminer::OperatorValue.new('in', [1,2,3], :integer)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "col IN (1,2,3)", param.to_string
  end

  def test_in_to_text
    opval1 = Crossbeams::Dataminer::OperatorValue.new('in', [1,2,3], :integer)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "col is any of 1, 2 or 3", param.to_text
  end

  def test_in_str
    opval1 = Crossbeams::Dataminer::OperatorValue.new('in', %w[1 2 3], :string)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "col IN ('1','2','3')", param.to_string
  end

  def test_in_or_null
    opval1 = Crossbeams::Dataminer::OperatorValue.new('in_or_null', [1,2,3], :integer)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "(col IN (1,2,3) OR col IS NULL)", param.to_string
  end

  def test_in_or_null_no_params
    opval1 = Crossbeams::Dataminer::OperatorValue.new('in_or_null', [], :integer)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "col IS NULL", param.to_string

    opval1 = Crossbeams::Dataminer::OperatorValue.new('in_or_null', nil, :string)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "col IS NULL", param.to_string
  end

  def test_in_or_null_to_text
    opval1 = Crossbeams::Dataminer::OperatorValue.new('in_or_null', [1,2,3], :integer)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "col is any of 1, 2 or 3 or is blank", param.to_text
  end

  def test_in_or_null_str
    opval1 = Crossbeams::Dataminer::OperatorValue.new('in_or_null', %w[1 2 3], :string)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "(col IN ('1','2','3') OR col IS NULL)", param.to_string
  end

  def test_empty_in
    opval1 = Crossbeams::Dataminer::OperatorValue.new('in', [], :integer)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "(1 = 2)", param.to_string
  end

  def test_empty_in_to_text
    opval1 = Crossbeams::Dataminer::OperatorValue.new('in', [], :integer)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "col check is ignored", param.to_text
  end

  def test_any_in_array
    opval1 = Crossbeams::Dataminer::OperatorValue.new('any', 1, :integer_array)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "1=ANY(col)", param.to_string
  end

  def test_any_in_array_to_text
    opval1 = Crossbeams::Dataminer::OperatorValue.new('any', 1, :integer_array)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "col array contains 1", param.to_text
  end

  def test_any_in_str_array
    opval1 = Crossbeams::Dataminer::OperatorValue.new('any', 'AA', :string_array)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "'AA'=ANY(col)", param.to_string
  end

  def test_any_in_str_array_to_text
    opval1 = Crossbeams::Dataminer::OperatorValue.new('any', 'AA', :string_array)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    assert_equal "col array contains 'AA'", param.to_text
  end

  def test_can_create_from_definition
    opval = Crossbeams::Dataminer::OperatorValue.new('=', 'FRED')
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval)
    p_def = Crossbeams::Dataminer::QueryParameterDefinition.new('col')
    n_param = Crossbeams::Dataminer::QueryParameter.from_definition(p_def, opval)
    assert_equal param.to_string, n_param.to_string
  end

  def test_can_create_from_definition_with_datatype
    opval1 = Crossbeams::Dataminer::OperatorValue.new('=', [123], :integer)
    opval2 = Crossbeams::Dataminer::OperatorValue.new('=', 123)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    p_def = Crossbeams::Dataminer::QueryParameterDefinition.new('col', data_type: :integer)
    n_param = Crossbeams::Dataminer::QueryParameter.from_definition(p_def, opval2)
    assert_equal param.to_string, n_param.to_string
  end

  def test_can_create_from_definition_without_datatype
    opval1 = Crossbeams::Dataminer::OperatorValue.new('=', [123], :integer)
    opval2 = Crossbeams::Dataminer::OperatorValue.new('=', 123)
    param = Crossbeams::Dataminer::QueryParameter.new('col', opval1)
    p_def = Crossbeams::Dataminer::QueryParameterDefinition.new('col')
    n_param = Crossbeams::Dataminer::QueryParameter.from_definition(p_def, opval2)
    refute_equal param.to_string, n_param.to_string
  end

  # def test_nulls_in_ast
  #   nulls = [
  #     ['is_null', '', 0],
  #     ['not_null', '', 1]
  #   ]
  #   nulls.each do |op, val, expect|
  #     opval = Crossbeams::Dataminer::OperatorValue.new(op, val)
  #     param = Crossbeams::Dataminer::QueryParameter.new('col', opval)
  #     ast = param.to_ast
  #     refute_nil ast['NULLTEST']
  #     assert_equal expect, ast['NULLTEST']['nulltesttype']
  #   end
  # end
  #
  # def test_between_operator
  #   opval = Crossbeams::Dataminer::OperatorValue.new('between', ['2015-08-01', '2015-08-31'])
  #   param = Crossbeams::Dataminer::QueryParameter.new('col', opval)
  #   ast = param.to_ast
  #   refute_nil ast['AEXPR AND']
  #   assert_equal '2015-08-01', ast['AEXPR AND']['lexpr']['AEXPR']['rexpr']['A_CONST']['val']
  #   assert_equal '2015-08-31', ast['AEXPR AND']['rexpr']['AEXPR']['rexpr']['A_CONST']['val']
  # end
  #TODO test reverse engineer WHERE clause...

  # TODO: test IN, AND and OR combinations.
  # opval = 'IN', [1,2,3]
end
