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
    assert_equal %Q{SELECT id, name FROM users WHERE name = 'Fred'}, @report.runnable_sql

    params = []
    params << Crossbeams::Dataminer::QueryParameter.new('name', Crossbeams::Dataminer::OperatorValue.new('=', "O'Reilly"))
    @report.replace_where(params)
    assert_equal %Q{SELECT id, name FROM users WHERE name = 'O''Reilly'}, @report.runnable_sql
  end

  def test_apply_no_params
    @report.sql = "SELECT id, name FROM users"
    @report.apply_params([])
    assert_equal %Q{SELECT id, name FROM users}, @report.runnable_sql
  end

  def test_runnable_for_mssql
    @report.sql = "SELECT id, name FROM users"
    @report.apply_params([])
    assert_equal %Q{SELECT id, name FROM users}, @report.runnable_sql_delimited
    assert_equal %Q{SELECT id, name FROM users}, @report.runnable_sql_delimited(:postgresl)
    assert_equal %Q{SELECT id, name FROM users}, @report.runnable_sql_delimited(:mssql)
  end

  def test_runnable_for_mssql_with_limit
    @report.sql = "SELECT id, name FROM users LIMIT 10"
    @report.apply_params([])
    assert_equal %Q{SELECT id, name FROM users LIMIT 10}, @report.runnable_sql_delimited
    assert_equal %Q{SELECT TOP 10 id, name FROM users}, @report.runnable_sql_delimited(:mssql)
  end

  def test_runnable_for_mssql_with_offset
    @report.sql = "SELECT id, name FROM users OFFSET 10 LIMIT 10"
    @report.apply_params([])
    assert_equal %Q{SELECT id, name FROM users LIMIT 10 OFFSET 10}, @report.runnable_sql_delimited
    assert_raises(Crossbeams::Dataminer::SyntaxError) { @report.runnable_sql_delimited(:mssql) }
  end

  def test_apply_params
    @report.sql = "SELECT id, name FROM users"
    params = []
    params << Crossbeams::Dataminer::QueryParameter.new('name', Crossbeams::Dataminer::OperatorValue.new('=', 'Fred'))
    params << Crossbeams::Dataminer::QueryParameter.new('logins', Crossbeams::Dataminer::OperatorValue.new('=', 12, :integer))
    @report.apply_params(params)
    assert_equal %Q{SELECT id, name FROM users WHERE name = 'Fred' AND logins = 12}, @report.runnable_sql
  end

  def test_apply_params_to_existing_where
    base_sql = "SELECT id, name FROM users"
    conditions = {'id = 2' => %Q{SELECT id, name FROM users WHERE id = 2 AND name = 'John'},
                  'id IS NULL' => %Q{SELECT id, name FROM users WHERE id IS NULL AND name = 'John'},
                  'id IS NOT NULL' => %Q{SELECT id, name FROM users WHERE id IS NOT NULL AND name = 'John'},
                  'active' => %Q{SELECT id, name FROM users WHERE active AND name = 'John'},
                  'NOT active' => %Q{SELECT id, name FROM users WHERE NOT active AND name = 'John'},
                  "id = 3 AND name <> 'Fred'" => %Q{SELECT id, name FROM users WHERE id = 3 AND name <> 'Fred' AND name = 'John'}}
    conditions.each do |cond, expect|
      @report.sql = base_sql + ' WHERE ' + cond
      params = []
      params << Crossbeams::Dataminer::QueryParameter.new('name', Crossbeams::Dataminer::OperatorValue.new('=', 'John'))
      @report.apply_params(params)
      assert_equal expect, @report.runnable_sql
    end
  end

  def test_apply_params_datatype
    base_sql = %Q{SELECT id, name FROM users}
    conditions = [[nil, '12', %Q{SELECT id, name FROM users WHERE id = '12'}],
                  [:integer, '12', %Q{SELECT id, name FROM users WHERE id = 12}],
                  [:string, '12', %Q{SELECT id, name FROM users WHERE id = '12'}],
                  [nil, 12, %Q{SELECT id, name FROM users WHERE id = '12'}],
                  [:integer, 12, %Q{SELECT id, name FROM users WHERE id = 12}],
                  # [:string, 12, %Q{SELECT id, name FROM users WHERE id = 12}]]
                  [:string, 12, %Q{SELECT id, name FROM users WHERE id = '12'}]]
    conditions.each do |data_type, id, expect|
      @report.sql = base_sql
      params = []
      params << Crossbeams::Dataminer::QueryParameter.new('id', Crossbeams::Dataminer::OperatorValue.new('=', id, data_type))
      @report.apply_params(params)
      assert_equal expect, @report.runnable_sql
    end
  end

  def test_change_sql_with_parameters_and_column_attributes
    start_sql = %Q{SELECT id, name FROM users}
    end_sql   = %Q{SELECT id, name, email FROM users}
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

  def test_query_param_ui_order
    @report.sql = %Q{SELECT id, name FROM users}
    @report.add_parameter_definition(Crossbeams::Dataminer::QueryParameterDefinition.new('ghi',
                                                            :caption       => 'Ghi',
                                                            :data_type     => :string,
                                                            :control_type  => :text,
                                                            :ui_priority   => 2,
                                                            :default_value => nil,
                                                            :list_def      => nil))
    @report.add_parameter_definition(Crossbeams::Dataminer::QueryParameterDefinition.new('abc',
                                                            :caption       => 'Abc',
                                                            :data_type     => :string,
                                                            :control_type  => :text,
                                                            :ui_priority   => 2,
                                                            :default_value => nil,
                                                            :list_def      => nil))
    @report.add_parameter_definition(Crossbeams::Dataminer::QueryParameterDefinition.new('def',
                                                            :caption       => 'Def',
                                                            :data_type     => :string,
                                                            :control_type  => :text,
                                                            :ui_priority   => 1,
                                                            :default_value => nil,
                                                            :list_def      => nil))
    expect_std = %w[Ghi Abc Def]
    expect_ord = %w[Def Abc Ghi]
    assert_equal expect_std, @report.query_parameter_definitions.map { |q| q.caption }
    assert_equal expect_ord, @report.ordered_query_parameter_definitions.map { |q| q.caption }
  end

  def test_cast_char_without_limit_override
    @report.sql = "SELECT CAST(id AS character varying) AS char_id FROM users"
    assert_equal %Q{SELECT id::varchar AS char_id FROM users}, @report.runnable_sql
  end

  def test_cast_num_without_limit_override
    @report.sql = "SELECT CAST(id AS numeric) AS num_id FROM users"
    assert_equal %Q{SELECT id::numeric AS num_id FROM users}, @report.runnable_sql
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

  def test_count_query
    queries = {
      'SELECT id, name AS login FROM users' => 'SELECT count(*) FROM users',
      'SELECT id, name AS login FROM users WHERE id = 23' => 'SELECT count(*) FROM users WHERE id = 23',
      'SELECT id, name AS login FROM users WHERE id = 23 ORDER BY id DESC' => 'SELECT count(*) FROM users WHERE id = 23',
      'SELECT id, name AS login FROM users LIMIT 3 OFFSET 20' => 'SELECT count(*) FROM users'
    }
    queries.each do |sql, expect|
      @report.sql = sql
      assert_equal sql, @report.runnable_sql
      assert_equal expect, @report.count_query
      assert_equal sql, @report.runnable_sql #...
    end
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
    expect           = %Q{SELECT id, name FROM users ORDER BY id DESC}
    assert_equal expect, @report.runnable_sql
  end

  def test_replacing_order_by
    @report.sql      = "SELECT id, name FROM users order by name;"
    @report.order_by = 'id desc'
    expect           = %Q{SELECT id, name FROM users ORDER BY id DESC}
    assert_equal expect, @report.runnable_sql
  end

  #TODO: Change dataminer so that it can run a function query as if SQL
  #      - with columns returned and params provided...
  def test_function_not_table
    # Should take params and add between brackets - retaining any existing params.
    skip "SELECT storeopeninghours_tostring AS tmp from storeopeninghours_tostring('123');"
  end

  def test_table_method_rejected_without_sql
    assert_raises(Crossbeams::Dataminer::Error) { @report.tables }
  end

  def test_table_alias_method_rejected_without_sql
    assert_raises(Crossbeams::Dataminer::Error) { @report.tables_or_aliases }
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

  def test_table_alias_method_returns_tables_or_aliases
    [{:sql    => 'SELECT id FROM users',
      :tables => ['users']},
     {:sql    => 'SELECT users.id, p.name FROM users JOIN people p ON p.id = users.person_id',
      :tables => ['users', 'p']},
     {:sql    => 'SELECT u.id, p.name FROM users u JOIN people p ON p.id = u.person_id',
      :tables => ['u', 'p']}].each do |conditions|
       @report.sql = conditions[:sql]
       conditions[:tables].each { |table| assert_includes @report.tables_or_aliases, table }
     end
  end

  def test_remove_column
    @report.sql      = "SELECT id, name, email FROM users;"
    @report.remove_columns('email')
    expect           = %Q{SELECT id, name FROM users}
    assert_equal expect, @report.runnable_sql

    @report.sql      = "SELECT u.id, u.name, u.email FROM users u;"
    @report.remove_columns('email')
    expect           = %Q{SELECT u.id, u.name FROM users u}
    assert_equal expect, @report.runnable_sql
  end

  def test_remove_columns
    @report.sql      = "SELECT id, name, email FROM users;"
    @report.remove_columns(['email', 'id'])
    expect           = %Q{SELECT name FROM users}
    assert_equal expect, @report.runnable_sql
  end

  def test_remove_grouped_column
    @report.sql      = "SELECT id, name, email, count(xx) FROM users GROUP BY id, name, email;"
    @report.remove_columns('email')
    expect           = %Q{SELECT id, name, count(xx) FROM users GROUP BY id, name}
    assert_equal expect, @report.runnable_sql

    @report.sql      = "SELECT u.id, u.name, u.email, count(xx) FROM users u GROUP BY u.id, u.name, u.email;"
    @report.remove_columns('email')
    expect           = %Q{SELECT u.id, u.name, count(xx) FROM users u GROUP BY u.id, u.name}
    assert_equal expect, @report.runnable_sql
  end

  def test_remove_grouped_columns
    @report.sql      = "SELECT id, name, email, count(xx) FROM users GROUP BY id, name, email;"
    @report.remove_columns(['email', 'id'])
    expect           = %Q{SELECT name, count(xx) FROM users GROUP BY name}
    assert_equal expect, @report.runnable_sql
  end

  def test_remove_ordered_column
    @report.sql      = "SELECT id, name, email FROM users ORDER BY id, name, email;"
    @report.remove_columns('email')
    expect           = %Q{SELECT id, name FROM users ORDER BY id, name}
    assert_equal expect, @report.runnable_sql

    @report.sql      = "SELECT u.id, u.name, u.email FROM users u ORDER BY u.id, u.name, u.email;"
    @report.remove_columns('email')
    expect           = %Q{SELECT u.id, u.name FROM users u ORDER BY u.id, u.name}
    assert_equal expect, @report.runnable_sql
  end

  def test_remove_ordered_columns
    @report.sql      = "SELECT id, name, email FROM users ORDER BY id, name, email;"
    @report.remove_columns(['email', 'id'])
    expect           = %Q{SELECT name FROM users ORDER BY name}
    assert_equal expect, @report.runnable_sql
  end

  def test_convert_columns_to_array
    @report.sql      = "SELECT id, name, email FROM users;"
    @report.convert_columns_to_array('combin', ['id', 'name'])
    expect           = %Q{SELECT ARRAY[id, name] AS combin, email FROM users}
    assert_equal expect, @report.runnable_sql
  end

  def test_parameter_description
    base_sql = %Q{SELECT "id", "name" FROM "users"}
    param_set = {
      id_eq:   Crossbeams::Dataminer::QueryParameter.new('id', Crossbeams::Dataminer::OperatorValue.new('=', 1, :integer)), # Might be good to have: ", display_values: { 1 => 'Voyage' }"
      id_gt:   Crossbeams::Dataminer::QueryParameter.new('id', Crossbeams::Dataminer::OperatorValue.new('>', 1, :integer)),
      id_gteq: Crossbeams::Dataminer::QueryParameter.new('id', Crossbeams::Dataminer::OperatorValue.new('>=', 1, :integer)),
      id_nteq: Crossbeams::Dataminer::QueryParameter.new('id', Crossbeams::Dataminer::OperatorValue.new('<>', 1, :integer)),
      id_lt:   Crossbeams::Dataminer::QueryParameter.new('id', Crossbeams::Dataminer::OperatorValue.new('<', 1, :integer)),
      id_lteq: Crossbeams::Dataminer::QueryParameter.new('id', Crossbeams::Dataminer::OperatorValue.new('<=', 1, :integer)),
      id_null: Crossbeams::Dataminer::QueryParameter.new('id', Crossbeams::Dataminer::OperatorValue.new('is_null', 1, :integer)),
      id_val:  Crossbeams::Dataminer::QueryParameter.new('id', Crossbeams::Dataminer::OperatorValue.new('not_null', 1, :integer)),
      id_in:   Crossbeams::Dataminer::QueryParameter.new('id', Crossbeams::Dataminer::OperatorValue.new('in', [1,2,3], :integer)),
      id_or:   Crossbeams::Dataminer::QueryParameter.new('id', Crossbeams::Dataminer::OperatorValue.new('=', [1,2,3], :integer), is_an_or_range: true),
      st_in:   Crossbeams::Dataminer::QueryParameter.new('nm', Crossbeams::Dataminer::OperatorValue.new('in', ['Joe','Pete'], :string)),
      st_sw:   Crossbeams::Dataminer::QueryParameter.new('nm', Crossbeams::Dataminer::OperatorValue.new('starts_with', 'Jo', :string)),
      st_ew:   Crossbeams::Dataminer::QueryParameter.new('nm', Crossbeams::Dataminer::OperatorValue.new('ends_with', 'han', :string)),
      st_cnt:  Crossbeams::Dataminer::QueryParameter.new('nm', Crossbeams::Dataminer::OperatorValue.new('contains', 'ete', :string)),
      true:    Crossbeams::Dataminer::QueryParameter.new('active', Crossbeams::Dataminer::OperatorValue.new('=', true, :boolean)),
      false:   Crossbeams::Dataminer::QueryParameter.new('active', Crossbeams::Dataminer::OperatorValue.new('=', false, :boolean)),
      between: Crossbeams::Dataminer::QueryParameter.new('dt', Crossbeams::Dataminer::OperatorValue.new('between', [Time.new(2018,1,1), Time.new(2018,1,3)], :date)),
    }

    sets = {
      [:id_eq] => ['id equals 1'],
      [:id_gt] => ['id greater than 1'],
      [:id_gteq] => ['id greater than or equal to 1'],
      [:id_nteq] => ['id not equal to 1'],
      [:id_lt] => ['id less than 1'],
      [:id_lteq] => ['id less than or equal to 1'],
      [:id_null] => ['id is blank'],
      [:id_val] => ['id is not blank'],
      [:id_in] => ['id is any of 1, 2 or 3'],
      [:id_or] => ['(id equals 1 OR id equals 2 OR id equals 3)'],
      [:st_in] => ["nm is any of 'Joe' or 'Pete'"],
      [:st_sw] => ["nm starts with 'Jo'"],
      [:st_ew] => ["nm ends with 'han'"],
      [:st_cnt] => ["nm contains 'ete'"],
      [:true] => ['is active'],
      [:false] => ['is not active'],
      [:between] => ["dt is between '2018-01-01 00:00:00 +0200' and '2018-01-03 00:00:00 +0200'"],
      [:id_gt, :st_in] => ['id greater than 1', "nm is any of 'Joe' or 'Pete'"]
    }
    sets.each do |keys, texts|
      @report.sql = base_sql
      params = []
      keys.each { |k| params << param_set[k] }
      @report.apply_params(params)
      assert_equal texts, @report.parameter_texts
    end
  end

  def test_cte_query
    cte = <<~SQL
      WITH identifiers as (
          SELECT DISTINCT cartons.palletizer_identifier_id,
                          contract_workers.first_name,
                          et.employment_type_code
          FROM cartons
                   LEFT JOIN contract_workers ON contract_workers.personnel_identifier_id=cartons.palletizer_identifier_id
                   LEFT JOIN employment_types et ON contract_workers.employment_type_id = et.id
          WHERE employment_type_code IS NULL OR employment_type_code='PACKERS')
      SELECT identifiers.palletizer_identifier_id, identifiers.first_name,
             identifiers.employment_type_code, COUNT(cartons.id) AS carton_count
      FROM cartons
               JOIN identifiers ON identifiers.palletizer_identifier_id = cartons.palletizer_identifier_id
      GROUP BY identifiers.palletizer_identifier_id,identifiers.first_name,identifiers.employment_type_code
    SQL

    @report.sql = cte
    assert_equal %w[palletizer_identifier_id first_name employment_type_code carton_count], @report.ordered_columns.map {|c| c.name }
  end
  #
  # def test_union_query
  #   union = <<~SQL
  #     SELECT 'with' AS got_value, COUNT(cartons.id) AS carton_count
  #     FROM cartons WHERE cartons.palletizer_identifier_id IS NOT NULL
  #     UNION
  #     SELECT 'without' AS got_value, COUNT(cartons.id) AS carton_count
  #     FROM cartons WHERE cartons.palletizer_identifier_id IS NULL;
  #   SQL
  #
  #   @report.sql = union
  #   assert_equal %w[got_value carton_count], @report.ordered_columns.map {|c| c.name }
  # end
end
