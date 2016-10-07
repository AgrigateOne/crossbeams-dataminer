require 'test_helper'

class ColumnTest < Minitest::Test

  def test_column_caption
    column = Dataminer::Column.new(1, {"val"=>{"ColumnRef"=>{"fields"=>[{"String"=>{"str"=>"b"}}, {"String"=>{"str"=>"name"}}], "location"=>7}}, "location"=>7})
    assert_equal 'Name', column.caption
  end

  def test_column_namespace_name_no_alias
    column = Dataminer::Column.new(1, {"val"=>{"ColumnRef"=>{"fields"=>[{"String"=>{"str"=>"name"}}], "location"=>7}}, "location"=>7})
    assert_equal 'name', column.namespaced_name
  end

  def test_column_namespace_name
    column = Dataminer::Column.new(1, {"val"=>{"ColumnRef"=>{"fields"=>[{"String"=>{"str"=>"b"}}, {"String"=>{"str"=>"name"}}], "location"=>7}}, "location"=>7})
    assert_equal 'b.name', column.namespaced_name
  end

  def test_column_override_caption
    column = Dataminer::Column.new(1, {"name"=>"surname", "val"=>{"ColumnRef"=>{"fields"=>[{"String"=>{"str"=>"b"}}, {"String"=>{"str"=>"name"}}], "location"=>7}}, "location"=>7})
    assert_equal 'Surname', column.caption
  end

  def test_column_override_name
    column = Dataminer::Column.new(1, {"name"=>"surname", "val"=>{"ColumnRef"=>{"fields"=>[{"String"=>{"str"=>"name"}}], "location"=>7}}, "location"=>7})
    assert_equal 'surname', column.name
  end

  def test_column_override_namespace_name
    column = Dataminer::Column.new(1, {"name"=>"surname", "val"=>{"ColumnRef"=>{"fields"=>[{"String"=>{"str"=>"b"}}, {"String"=>{"str"=>"name"}}], "location"=>7}}, "location"=>7})
    assert_equal 'b.name', column.namespaced_name
  end

  def test_column_function_name
    column = Dataminer::Column.new(1, {"name"=>"inv_month", "val"=> {"FuncCall"=> {"funcname"=>[{"String"=>{"str"=>"to_char"}}],
                                       "args"=> [{"ColumnRef"=> {"fields"=>[{"String"=>{"str"=>"service_provider_invoices"}},
                                      {"String"=>{"str"=>"invoice_date"}}], "location"=>15}},
    {"A_Const"=>{"val"=>{"String"=>{"str"=>"YYYY-MM"}}, "location"=>59}}], "location"=>7}}, "location"=>7})
    assert_equal 'inv_month', column.name
  end


  def test_column_function_namespace_name
    column = Dataminer::Column.new(1, {"name"=>"inv_month", "val"=> {"FuncCall"=> {"funcname"=>[{"String"=>{"str"=>"to_char"}}],
                                       "args"=> [{"ColumnRef"=> {"fields"=>[{"String"=>{"str"=>"service_provider_invoices"}},
                                      {"String"=>{"str"=>"invoice_date"}}], "location"=>15}},
    {"A_Const"=>{"val"=>{"String"=>{"str"=>"YYYY-MM"}}, "location"=>59}}], "location"=>7}}, "location"=>7})
    # assert_equal 'inv_month', column.namespaced_name
    assert_nil column.namespaced_name
  end

end

