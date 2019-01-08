require 'test_helper'

class ColumnTest < Minitest::Test

  BASIC_COLUMN = {"val"=>{"ColumnRef"=>{"fields"=>[{"String"=>{"str"=>"b"}}, {"String"=>{"str"=>"name"}}], "location"=>7}}, "location"=>7}

  def test_column_caption
    column = Crossbeams::Dataminer::Column.new(1, {"val"=>{"ColumnRef"=>{"fields"=>[{"String"=>{"str"=>"b"}}, {"String"=>{"str"=>"name"}}], "location"=>7}}, "location"=>7})
    assert_equal 'Name', column.caption
  end

  def test_column_namespace_name_no_alias
    column = Crossbeams::Dataminer::Column.new(1, {"val"=>{"ColumnRef"=>{"fields"=>[{"String"=>{"str"=>"name"}}], "location"=>7}}, "location"=>7})
    assert_equal 'name', column.namespaced_name
  end

  def test_column_namespace_name
    column = Crossbeams::Dataminer::Column.new(1, {"val"=>{"ColumnRef"=>{"fields"=>[{"String"=>{"str"=>"b"}}, {"String"=>{"str"=>"name"}}], "location"=>7}}, "location"=>7})
    assert_equal 'b.name', column.namespaced_name
  end

  def test_column_override_caption
    column = Crossbeams::Dataminer::Column.new(1, {"name"=>"surname", "val"=>{"ColumnRef"=>{"fields"=>[{"String"=>{"str"=>"b"}}, {"String"=>{"str"=>"name"}}], "location"=>7}}, "location"=>7})
    assert_equal 'Surname', column.caption
  end

  def test_column_override_name
    column = Crossbeams::Dataminer::Column.new(1, {"name"=>"surname", "val"=>{"ColumnRef"=>{"fields"=>[{"String"=>{"str"=>"name"}}], "location"=>7}}, "location"=>7})
    assert_equal 'surname', column.name
  end

  def test_column_override_namespace_name
    column = Crossbeams::Dataminer::Column.new(1, {"name"=>"surname", "val"=>{"ColumnRef"=>{"fields"=>[{"String"=>{"str"=>"b"}}, {"String"=>{"str"=>"name"}}], "location"=>7}}, "location"=>7})
    assert_equal 'b.name', column.namespaced_name
  end

  def test_column_function_name
    column = Crossbeams::Dataminer::Column.new(1, {"name"=>"inv_month", "val"=> {"FuncCall"=> {"funcname"=>[{"String"=>{"str"=>"to_char"}}],
                                       "args"=> [{"ColumnRef"=> {"fields"=>[{"String"=>{"str"=>"service_provider_invoices"}},
                                      {"String"=>{"str"=>"invoice_date"}}], "location"=>15}},
    {"A_Const"=>{"val"=>{"String"=>{"str"=>"YYYY-MM"}}, "location"=>59}}], "location"=>7}}, "location"=>7})
    assert_equal 'inv_month', column.name
  end


  def test_column_function_namespace_name
    column = Crossbeams::Dataminer::Column.new(1, {"name"=>"inv_month", "val"=> {"FuncCall"=> {"funcname"=>[{"String"=>{"str"=>"to_char"}}],
                                       "args"=> [{"ColumnRef"=> {"fields"=>[{"String"=>{"str"=>"service_provider_invoices"}},
                                      {"String"=>{"str"=>"invoice_date"}}], "location"=>15}},
    {"A_Const"=>{"val"=>{"String"=>{"str"=>"YYYY-MM"}}, "location"=>59}}], "location"=>7}}, "location"=>7})
    # assert_equal 'inv_month', column.namespaced_name
    assert_nil column.namespaced_name
  end

  def test_width_option
    column = Crossbeams::Dataminer::Column.new(1, BASIC_COLUMN)
    assert_nil column.width
    column = Crossbeams::Dataminer::Column.new(1, BASIC_COLUMN, width: 40)
    assert_equal 40, column.width
  end

  def test_pinned_option
    column = Crossbeams::Dataminer::Column.new(1, BASIC_COLUMN)
    assert_nil column.pinned
    column = Crossbeams::Dataminer::Column.new(1, BASIC_COLUMN, pinned: 'left')
    assert_equal 'left', column.pinned
  end

  def test_format_option
    column = Crossbeams::Dataminer::Column.new(1, BASIC_COLUMN)
    assert_nil column.format
    column = Crossbeams::Dataminer::Column.new(1, BASIC_COLUMN, format: 'delimited')
    assert_equal 'delimited', column.format
  end

  def test_group_by_seq_option
    column = Crossbeams::Dataminer::Column.new(1, BASIC_COLUMN)
    assert_nil column.group_by_seq
    column = Crossbeams::Dataminer::Column.new(1, BASIC_COLUMN, group_by_seq: 2)
    assert_equal 2, column.group_by_seq
  end

  def test_boolean_options
    column = Crossbeams::Dataminer::Column.new(1, BASIC_COLUMN)
    %i[hide groupable group_sum group_avg group_min group_max].each do |att|
      refute column.send(att)

      opt = { att => true }
      true_column = Crossbeams::Dataminer::Column.new(1, BASIC_COLUMN, opt)
      assert true_column.send(att)
    end
  end
end
