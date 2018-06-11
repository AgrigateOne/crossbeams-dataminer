require 'test_helper'

class ReportTest < Minitest::Test
  def setup
    @report = Crossbeams::Dataminer::Report.new
  end

  def test_that_it_rejects_select_star
    assert_raises(ArgumentError) { @report.sql = "SELECT * FROM users;" }
  end

  def test_that_it_rejects_insert
    assert_raises(ArgumentError) { @report.sql = "INSERT INTO users (id, name) VALUES(1, 'abc');" }
  end

  def test_that_it_rejects_update
    assert_raises(ArgumentError) { @report.sql = "UPDATE users SET name = 'abc';" }
  end

  def test_that_it_rejects_delete
    assert_raises(ArgumentError) { @report.sql = "DELETE FROM users;" }
  end

  def test_that_it_handles_invalid_syntax
    assert_raises(Crossbeams::Dataminer::SyntaxError) { @report.sql = "SELECT * FrdOM users;" }
  end

  def test_that_it_does_not_reject_select_specific
    @report.sql = "SELECT id, name FROM users;"
    assert_equal %Q{SELECT id, name FROM users;}, @report.sql
  end

  def test_that_it_handles_named_cols
    @report.sql = "SELECT id, name AS login FROM users;"
    assert_equal ['id', 'login'], @report.ordered_columns.map {|c| c.name }
  end

  def test_replace_where
    @report.sql = "SELECT id, name FROM users WHERE id = 21"
    params = []
    params << Crossbeams::Dataminer::QueryParameter.new('name', Crossbeams::Dataminer::OperatorValue.new('=', 'Fred'))
    @report.replace_where(params)
    assert_equal %Q{SELECT "id", "name" FROM "users" WHERE "name" = 'Fred'}, @report.runnable_sql
  end

  def test_apply_no_params
    @report.sql = "SELECT id, name FROM users"
    @report.apply_params([])
    assert_equal %Q{SELECT "id", "name" FROM "users"}, @report.runnable_sql
  end

  def test_runnable_for_mssql
    @report.sql = "SELECT id, name FROM users"
    @report.apply_params([])
    assert_equal %Q{SELECT "id", "name" FROM "users"}, @report.runnable_sql_delimited
    assert_equal %Q{SELECT id, name FROM users}, @report.runnable_sql_delimited(:mssql)
  end

  def test_apply_params
    @report.sql = "SELECT id, name FROM users"
    params = []
    params << Crossbeams::Dataminer::QueryParameter.new('name', Crossbeams::Dataminer::OperatorValue.new('=', 'Fred'))
    params << Crossbeams::Dataminer::QueryParameter.new('logins', Crossbeams::Dataminer::OperatorValue.new('=', 12, :integer))
    @report.apply_params(params)
    # assert_equal "SELECT id, name FROM users WHERE name = 'Fred' AND logins = 12", @report.runnable_sql
    assert_equal %Q{SELECT "id", "name" FROM "users" WHERE "name" = 'Fred' AND "logins" = 12}, @report.runnable_sql
  end

  def test_apply_params_to_existing_where
    base_sql = "SELECT id, name FROM users"
    conditions = {'id = 2' => %Q{SELECT "id", "name" FROM "users" WHERE "id" = 2 AND "name" = 'John'},
                  'id IS NULL' => %Q{SELECT "id", "name" FROM "users" WHERE "id" IS NULL AND "name" = 'John'},
                  'id IS NOT NULL' => %Q{SELECT "id", "name" FROM "users" WHERE "id" IS NOT NULL AND "name" = 'John'},
                  'active' => %Q{SELECT "id", "name" FROM "users" WHERE "active" AND "name" = 'John'},
                  'NOT active' => %Q{SELECT "id", "name" FROM "users" WHERE NOT "active" AND "name" = 'John'},
                  "id = 3 AND name <> 'Fred'" => %Q{SELECT "id", "name" FROM "users" WHERE "id" = 3 AND "name" <> 'Fred' AND "name" = 'John'}}
    conditions.each do |cond, expect|
      @report.sql = base_sql + ' WHERE ' + cond
      params = []
      params << Crossbeams::Dataminer::QueryParameter.new('name', Crossbeams::Dataminer::OperatorValue.new('=', 'John'))
      @report.apply_params(params)
      assert_equal expect, @report.runnable_sql
    end
  end

  def test_apply_params_datatype
    base_sql = %Q{SELECT "id", "name" FROM "users"}
    conditions = [[nil, '12', %Q{SELECT "id", "name" FROM "users" WHERE "id" = '12'}],
                  [:integer, '12', %Q{SELECT "id", "name" FROM "users" WHERE "id" = 12}],
                  [:string, '12', %Q{SELECT "id", "name" FROM "users" WHERE "id" = '12'}],
                  [nil, 12, %Q{SELECT "id", "name" FROM "users" WHERE "id" = '12'}],
                  [:integer, 12, %Q{SELECT "id", "name" FROM "users" WHERE "id" = 12}],
                  # [:string, 12, %Q{SELECT "id", "name" FROM "users" WHERE "id" = 12}]]
                  [:string, 12, %Q{SELECT "id", "name" FROM "users" WHERE "id" = '12'}]]
    conditions.each do |data_type, id, expect|
      @report.sql = base_sql
      params = []
      params << Crossbeams::Dataminer::QueryParameter.new('id', Crossbeams::Dataminer::OperatorValue.new('=', id, data_type))
      @report.apply_params(params)
      assert_equal expect, @report.runnable_sql
    end
  end

  def test_change_sql_with_parameters_and_column_attributes
    start_sql = %Q{SELECT "id", "name" FROM "users"}
    end_sql   = %Q{SELECT "id", "name", "email" FROM "users"}
    @report.sql = start_sql
    @report.columns['name'].hide = true
    @report.add_parameter_definition(Crossbeams::Dataminer::QueryParameterDefinition.new('name',
                                                            :caption       => 'Login',
                                                            :data_type     => :string,
                                                            :control_type  => :text,
                                                            :ui_priority   => 1,
                                                            :default_value => nil,
                                                            :list_def      => nil))
    @report.sql = end_sql
    assert_equal 1, @report.query_parameter_definitions.length
    assert @report.columns['name'].hide
  end

  def test_cast_char_without_limit_override
    @report.sql = "SELECT CAST(id AS character varying) AS char_id FROM users"
    assert_equal %Q{SELECT "id"::varchar AS char_id FROM "users"}, @report.runnable_sql
  end

  def test_cast_num_without_limit_override
    @report.sql = "SELECT CAST(id AS numeric) AS num_id FROM users"
    assert_equal %Q{SELECT "id"::numeric AS num_id FROM "users"}, @report.runnable_sql
  end

  def test_find_column
    @report.sql = "SELECT id, name AS login FROM users;"
    assert_equal 'id', @report.column('id').name
    assert_equal 'login', @report.column('login').name
    assert_equal 'name', @report.column('login').namespaced_name
  end

  def test_column_order
    @report.sql = "SELECT id, name AS login FROM users;"
    @report.columns['id'].sequence_no = 3
    assert_equal ['login','id'], @report.ordered_columns.map {|a| a.name }
  end

  def test_unique_column_names
    assert_raises(ArgumentError) { @report.sql = "SELECT id, name, id FROM users;" }
    assert_raises(ArgumentError) { @report.sql = "SELECT id, name, another_field AS id FROM users;" }
  end

  def test_unigue_parameter_definitions
    @report.sql = "SELECT id, name AS login FROM users;"
    @report.add_parameter_definition(Crossbeams::Dataminer::QueryParameterDefinition.new('name',
                                                            :caption       => 'Login',
                                                            :data_type     => :string,
                                                            :control_type  => :text,
                                                            :ui_priority   => 1,
                                                            :default_value => nil,
                                                            :list_def      => nil))
    assert_raises(ArgumentError) { @report.add_parameter_definition(Crossbeams::Dataminer::QueryParameterDefinition.new('name',
                                                            :caption       => 'Login',
                                                            :data_type     => :string,
                                                            :control_type  => :text,
                                                            :ui_priority   => 1,
                                                            :default_value => nil,
                                                            :list_def      => nil)) }
  end

  def test_portable_definition
    @report.sql = "SELECT id, name AS login FROM users;"
    @report.columns['id'].sequence_no = 3
    @report.columns['id'].caption = 'TheId'
    @report.add_parameter_definition( Crossbeams::Dataminer::QueryParameterDefinition.new('name',
                                                            :caption       => 'Login',
                                                            :data_type     => :string,
                                                            :control_type  => :text,
                                                            :ui_priority   => 1,
                                                            :default_value => nil,
                                                            :list_def      => nil))
    portable = @report.to_hash
    assert 'TheId' == portable[:columns]['id'][:caption]
    assert 3 == portable[:columns]['id'][:sequence_no]
    assert 'Login' == portable[:query_parameter_definitions].first[:caption]
  end

  def test_recreate_definition
    @report.sql = "SELECT id, name AS login FROM users;"
    @report.columns['id'].sequence_no = 3
    @report.columns['id'].caption = 'TheId'
    @report.add_parameter_definition( Crossbeams::Dataminer::QueryParameterDefinition.new('name',
                                                            :caption       => 'Login',
                                                            :data_type     => :string,
                                                            :control_type  => :text,
                                                            :ui_priority   => 1,
                                                            :default_value => nil,
                                                            :list_def      => nil))
    portable = @report.to_hash
    rpt = Crossbeams::Dataminer::Report.new
    rpt.update_from_hash(portable)
    assert rpt.caption == @report.caption
    assert rpt.columns['id'].sequence_no == 3
    assert rpt.columns['id'].caption     == 'TheId'
    assert rpt.query_parameter_definitions.length == @report.query_parameter_definitions.length
    assert_kind_of Hash, rpt.external_settings
  end

  def test_external_settings
    @report.sql = "SELECT id, name AS login FROM users;"
    @report.external_settings[:tester] = 'tester'
    portable = @report.to_hash
    assert_equal 'tester', portable[:external_settings][:tester]

    portable[:external_settings][:tester] = 'changed'
    @report.update_from_hash(portable)
    assert_equal 'changed', @report.external_settings[:tester]
  end

  def test_yaml_persistor
    @report.sql = "SELECT id, name AS login FROM users;"
    @report.columns['id'].sequence_no = 3
    @report.columns['id'].caption = 'TheId'
    @report.add_parameter_definition( Crossbeams::Dataminer::QueryParameterDefinition.new('name',
                                                            :caption       => 'Login',
                                                            :data_type     => :string,
                                                            :control_type  => :text,
                                                            :ui_priority   => 1,
                                                            :default_value => nil,
                                                            :list_def      => nil))
    orig = @report.to_hash
    fn = 'testyml.yml'
    yp = Crossbeams::Dataminer::YamlPersistor.new(fn)
    @report.save(yp)
    begin
      rpt = Crossbeams::Dataminer::Report.load(yp)
      assert orig == rpt.to_hash
    ensure
      File.delete(fn)
    end
  end

  def test_find_param_def
    @report.sql = "SELECT id, name AS login FROM users;"
    @report.add_parameter_definition(Crossbeams::Dataminer::QueryParameterDefinition.new('name',
                                                            :caption       => 'Login',
                                                            :data_type     => :string,
                                                            :control_type  => :text,
                                                            :ui_priority   => 1,
                                                            :default_value => nil,
                                                            :list_def      => nil))
    assert_equal 'Login', @report.parameter_definition('name').caption
    assert_nil  @report.parameter_definition('no_such_name')
  end

  def test_adding_order_by
    @report.sql      = "SELECT id, name FROM users;"
    @report.order_by = 'id DESC'
    expect           = %Q{SELECT "id", "name" FROM "users" ORDER BY "id" DESC}
    assert_equal expect, @report.runnable_sql
  end

  def test_replacing_order_by
    @report.sql      = "SELECT id, name FROM users order by name;"
    @report.order_by = 'id desc'
    expect           = %Q{SELECT "id", "name" FROM "users" ORDER BY "id" DESC}
    assert_equal expect, @report.runnable_sql
  end

  #TODO: Change dataminer so that it can run a function query as if SQL
  #      - with columns returned and params provided...
  def test_function_not_table
    # Should take params and add between brackets - retaining any existing params.
    skip "SELECT storeopeninghours_tostring AS tmp from storeopeninghours_tostring('123');"
  end

  def test_table_method_rejected_without_sql
    assert_raises(RuntimeError) { @report.tables }
  end

  def test_table_method_returns_tables
    [{:sql    => 'SELECT id FROM users',
      :tables => ['users']},
     {:sql    => 'SELECT u.id, p.name FROM users u JOIN people p ON p.id = u.person_id',
      :tables => ['users', 'people']}].each do |conditions|
       @report.sql = conditions[:sql]
       conditions[:tables].each { |table| assert_includes @report.tables, table }
     end
  end

  def test_remove_column
    @report.sql      = "SELECT id, name, email FROM users;"
    @report.remove_columns('email')
    expect           = %Q{SELECT "id", "name" FROM "users"}
    assert_equal expect, @report.runnable_sql
  end

  def test_remove_columns
    @report.sql      = "SELECT id, name, email FROM users;"
    @report.remove_columns(['email', 'id'])
    expect           = %Q{SELECT "name" FROM "users"}
    assert_equal expect, @report.runnable_sql
  end

  def test_remove_grouped_column
    @report.sql      = "SELECT id, name, email, count(xx) FROM users GROUP BY id, name, email;"
    @report.remove_columns('email')
    expect           = %Q{SELECT "id", "name", count("xx") FROM "users" GROUP BY "id", "name"}
    assert_equal expect, @report.runnable_sql
  end

  def test_remove_grouped_columns
    @report.sql      = "SELECT id, name, email, count(xx) FROM users GROUP BY id, name, email;"
    @report.remove_columns(['email', 'id'])
    expect           = %Q{SELECT "name", count("xx") FROM "users" GROUP BY "name"}
    assert_equal expect, @report.runnable_sql
  end

  def test_remove_ordered_column
    @report.sql      = "SELECT id, name, email FROM users ORDER BY id, name, email;"
    @report.remove_columns('email')
    expect           = %Q{SELECT "id", "name" FROM "users" ORDER BY "id", "name"}
    assert_equal expect, @report.runnable_sql
  end

  def test_remove_ordered_columns
    @report.sql      = "SELECT id, name, email FROM users ORDER BY id, name, email;"
    @report.remove_columns(['email', 'id'])
    expect           = %Q{SELECT "name" FROM "users" ORDER BY "name"}
    assert_equal expect, @report.runnable_sql
  end

  def test_convert_columns_to_array
    @report.sql      = "SELECT id, name, email FROM users;"
    @report.convert_columns_to_array('combin', ['id', 'name'])
    expect           = %Q{SELECT ARRAY["id", "name"] AS combin, "email" FROM "users"}
    assert_equal expect, @report.runnable_sql
  end
end
