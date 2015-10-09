require 'test_helper'

class QueryParameterTest < Minitest::Test

  def test_defaults
    param = Dataminer::QueryParameter.new('col')
    assert_equal '=', param.operator
  end

  def test_valid_operators
    param = Dataminer::QueryParameter.new('col')
    valids = %w{= >= <= <> > < between starts_with ends_with contains in not_null is_null}
    invalids = %w{12 www isnt == like}
    valids.each do |op|
      assert param.operator = op
    end
    invalids.each do |op|
      assert_raises(ArgumentError) {  param.operator = op }
    end
  end

  def test_operator_translations
    same_ops           = %w{= >= <= <> > < between in}
    ops                = Hash[same_ops.zip same_ops]
    ops['is_null']     = 'is'
    ops['not_null']    = 'is not'
    ops['starts_with'] = '~~'
    ops['ends_with']   = '~~'
    ops['contains']    = '~~'

    ops.each do |in_op, out_op|
      param = Dataminer::QueryParameter.new('col', :operator => in_op)
      op, _ = param.translate_expression
      assert_equal out_op, op
    end
  end

  def test_value_translations
    {true => 't', false => 'f'}.each do |in_val, out_val|
      param = Dataminer::QueryParameter.new('col', :operator => '=', :value => in_val)
      _, val = param.translate_expression
      assert_equal out_val, val
    end
  end

  def test_like_operator_value_translations
    {'starts_with' => "VAL%", 'contains' => "%VAL%", 'ends_with' => '%VAL'}.each do |in_op, out_val|
      param = Dataminer::QueryParameter.new('col', :operator => in_op, :value => 'VAL')
      op, val = param.translate_expression
      assert_equal '~~', op
      assert_equal out_val, val
    end
  end

  def test_null_test_value_translations
    {'is_null' => {:op => 'is', :val => 'NULL', :from => 'xxx'}, 'not_null' => {:op => 'is not', :val => 'NULL', :from => 'xxx'}}.each do |in_op, opts|
      param = Dataminer::QueryParameter.new('col', :operator => in_op, :value => opts[:from])
      op, val = param.translate_expression
      assert_equal opts[:op], op
      assert_equal opts[:val], val
    end
  end

  def test_nulls_in_ast
    nulls = [
      ['is_null', '', 0],
      ['not_null', '', 1]
    ]
    nulls.each do |op, val, expect|
      param = Dataminer::QueryParameter.new('col', :operator => op, :value => val)
      ast = param.to_ast
      refute_nil ast['NULLTEST']
      assert_equal expect, ast['NULLTEST']['nulltesttype']
    end
  end

  def test_between_operator
    param = Dataminer::QueryParameter.new('col', :operator => 'between', :from_value => '2015-08-01', :to_value => '2015-08-31')
    ast = param.to_ast
    refute_nil ast['AEXPR AND']
    assert_equal '2015-08-01', ast['AEXPR AND']['lexpr']['AEXPR']['rexpr']['A_CONST']['val']
    assert_equal '2015-08-31', ast['AEXPR AND']['rexpr']['AEXPR']['rexpr']['A_CONST']['val']
  end

  def test_invalid_between_operator
    param = Dataminer::QueryParameter.new('col', :operator => 'between', :from_value => '2015-08-01')
    assert_raises(ArgumentError) { param.to_ast }

    param = Dataminer::QueryParameter.new('col', :operator => 'between', :from_value => '2015-08-01', :to_value => '')
    assert_raises(ArgumentError) { param.to_ast }

    param = Dataminer::QueryParameter.new('col', :operator => 'between', :from_value => '2015-08-01', :to_value => '2015-01-01')
    assert_raises(ArgumentError) { param.to_ast }
  end
  #TODO test reverse engineer WHERE clause...

end
