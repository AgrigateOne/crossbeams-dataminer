require 'test_helper'

class OperatorValueTest < Minitest::Test


  def test_valid_operators
    valids = %w{= >= <= <> > < between starts_with ends_with contains in not_null is_null}
    invalids = %w{12 www isnt == like}
    valids.each do |op|
      Crossbeams::Dataminer::OperatorValue.new(op, [1,2])
      #assert param.operator = op
    end
    invalids.each do |op|
      assert_raises(ArgumentError) {  Crossbeams::Dataminer::OperatorValue.new(op, [1,2]) }
    end
  end

  def test_operator_for_sql
    same_ops           = %w{= >= <= <> > < between in}
    ops                = Hash[same_ops.zip same_ops]
    ops['is_null']     = 'is'
    ops['not_null']    = 'is not'
    ops['starts_with'] = '~~'
    ops['ends_with']   = '~~'
    ops['contains']    = '~~'

    ops.each do |in_op, out_op|
      opval = Crossbeams::Dataminer::OperatorValue.new(in_op, [1,2])
      op = opval.operator_for_sql
      assert_equal out_op, op
    end
  end

  def test_values_for_sql
    {true => ["'t'"], false => ["'f'"]}.each do |in_val, out_val|
      opval = Crossbeams::Dataminer::OperatorValue.new('=', in_val)
      val = opval.values_for_sql
      assert_equal out_val, val
    end
  end

  def test_like_operator_values_for_sql
    {'starts_with' => [ "'VAL%'" ], 'contains' => [ "'%VAL%'" ], 'ends_with' => [ "'%VAL'" ]}.each do |in_op, out_val|
      opval = Crossbeams::Dataminer::OperatorValue.new(in_op, 'VAL')
      val = opval.values_for_sql
      assert_equal out_val, val
    end
  end

  def test_null_test_values_for_sql
    {'is_null' => {:op => 'is', :val => [ 'NULL' ], :from => 'xxx'}, 'not_null' => {:op => 'is not', :val => [ 'NULL' ], :from => 'xxx'}}.each do |in_op, opts|
      opval = Crossbeams::Dataminer::OperatorValue.new(in_op, opts[:from])
      val = opval.values_for_sql
      assert_equal opts[:val], val
    end
  end

  def test_invalid_between_operator
    assert_raises(ArgumentError) { Crossbeams::Dataminer::OperatorValue.new('between', '2015-08-01') }
    assert_raises(ArgumentError) { Crossbeams::Dataminer::OperatorValue.new('between', ['2015-08-01', '']) }
    assert_raises(ArgumentError) { Crossbeams::Dataminer::OperatorValue.new('between', ['2015-08-01', '2015-01-01']) }
  end

end
