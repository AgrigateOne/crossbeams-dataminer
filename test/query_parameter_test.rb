require 'test_helper'

class QueryParameterTest < Minitest::Test

  def test_with_datatype
    opval1 = Dataminer::OperatorValue.new('=', [123], :integer)
    param = Dataminer::QueryParameter.new('col', opval1)
    assert_equal "col = 123", param.to_string
  end

  def test_can_create_from_definition
    opval = Dataminer::OperatorValue.new('=', 'FRED')
    param = Dataminer::QueryParameter.new('col', opval)
    p_def = Dataminer::QueryParameterDefinition.new('col')
    n_param = Dataminer::QueryParameter.from_definition(p_def, opval)
    assert_equal param.to_string, n_param.to_string
  end

  def test_can_create_from_definition_with_datatype
    opval1 = Dataminer::OperatorValue.new('=', [123], :integer)
    opval2 = Dataminer::OperatorValue.new('=', 123)
    param = Dataminer::QueryParameter.new('col', opval1)
    p_def = Dataminer::QueryParameterDefinition.new('col', data_type: :integer)
    n_param = Dataminer::QueryParameter.from_definition(p_def, opval2)
    assert_equal param.to_string, n_param.to_string
  end

  def test_can_create_from_definition_without_datatype
    opval1 = Dataminer::OperatorValue.new('=', [123], :integer)
    opval2 = Dataminer::OperatorValue.new('=', 123)
    param = Dataminer::QueryParameter.new('col', opval1)
    p_def = Dataminer::QueryParameterDefinition.new('col')
    n_param = Dataminer::QueryParameter.from_definition(p_def, opval2)
    refute_equal param.to_string, n_param.to_string
  end

  # def test_nulls_in_ast
  #   nulls = [
  #     ['is_null', '', 0],
  #     ['not_null', '', 1]
  #   ]
  #   nulls.each do |op, val, expect|
  #     opval = Dataminer::OperatorValue.new(op, val)
  #     param = Dataminer::QueryParameter.new('col', opval)
  #     ast = param.to_ast
  #     refute_nil ast['NULLTEST']
  #     assert_equal expect, ast['NULLTEST']['nulltesttype']
  #   end
  # end
  #
  # def test_between_operator
  #   opval = Dataminer::OperatorValue.new('between', ['2015-08-01', '2015-08-31'])
  #   param = Dataminer::QueryParameter.new('col', opval)
  #   ast = param.to_ast
  #   refute_nil ast['AEXPR AND']
  #   assert_equal '2015-08-01', ast['AEXPR AND']['lexpr']['AEXPR']['rexpr']['A_CONST']['val']
  #   assert_equal '2015-08-31', ast['AEXPR AND']['rexpr']['AEXPR']['rexpr']['A_CONST']['val']
  # end
  #TODO test reverse engineer WHERE clause...

  # TODO: test IN, AND and OR combinations.
  # opval = 'IN', [1,2,3]
end
