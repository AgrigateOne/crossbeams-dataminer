require 'test_helper'

class QueryParameterTest < Minitest::Test

  def test_nulls_in_ast
    nulls = [
      ['is_null', '', 0],
      ['not_null', '', 1]
    ]
    nulls.each do |op, val, expect|
      opval = Dataminer::OperatorValue.new(op, val)
      param = Dataminer::QueryParameter.new('col', opval)
      ast = param.to_ast
      refute_nil ast['NULLTEST']
      assert_equal expect, ast['NULLTEST']['nulltesttype']
    end
  end

  def test_between_operator
    opval = Dataminer::OperatorValue.new('between', ['2015-08-01', '2015-08-31'])
    param = Dataminer::QueryParameter.new('col', opval)
    ast = param.to_ast
    refute_nil ast['AEXPR AND']
    assert_equal '2015-08-01', ast['AEXPR AND']['lexpr']['AEXPR']['rexpr']['A_CONST']['val']
    assert_equal '2015-08-31', ast['AEXPR AND']['rexpr']['AEXPR']['rexpr']['A_CONST']['val']
  end
  #TODO test reverse engineer WHERE clause...

end
