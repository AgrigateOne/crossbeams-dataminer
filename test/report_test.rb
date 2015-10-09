require 'test_helper'

class ReportTest < Minitest::Test
  def setup
    @report = Dataminer::Report.new
  end

  def test_that_it_rejects_select_star
    assert_raises(ArgumentError) { @report.sql = "SELECT * FROM users;" }
  end

  def test_that_it_handles_invalid_syntax
    assert_raises(Dataminer::SyntaxError) { @report.sql = "SELECT * FrdOM users;" }
  end

  def test_that_it_does_not_reject_select_specific
    @report.sql = "SELECT id, name FROM users;"
    assert_equal "SELECT id, name FROM users;", @report.sql
  end

  def test_that_it_handles_named_cols
    @report.sql = "SELECT id, name AS login FROM users;"
    assert_equal ['id', 'login'], @report.columns.map {|c| c.name }
  end

  def test_replace_where
    @report.sql = "SELECT id, name FROM users WHERE id = 21"
    params = []
    params << Dataminer::QueryParameter.new('name', Dataminer::OperatorValue.new('=', 'Fred'))
    @report.replace_where(params)
    assert_equal "SELECT id, name FROM users WHERE name = 'Fred'", @report.runnable_sql
  end

  def test_apply_no_params
    @report.sql = "SELECT id, name FROM users"
    @report.apply_params([])
    assert_equal "SELECT id, name FROM users", @report.runnable_sql
  end

  def test_apply_params
    @report.sql = "SELECT id, name FROM users"
    params = []
    params << Dataminer::QueryParameter.new('name', Dataminer::OperatorValue.new('=', 'Fred'))
    params << Dataminer::QueryParameter.new('logins', Dataminer::OperatorValue.new('=', 12))
    @report.apply_params(params)
    assert_equal "SELECT id, name FROM users WHERE name = 'Fred' AND logins = 12", @report.runnable_sql
  end

  def test_apply_params_to_existing_where
    base_sql = "SELECT id, name FROM users"
    conditions = {'id = 2' => "SELECT id, name FROM users WHERE id = 2 AND name = 'John'",
                  'id IS NULL' => "SELECT id, name FROM users WHERE id IS NULL AND name = 'John'",
                  'id IS NOT NULL' => "SELECT id, name FROM users WHERE id IS NOT NULL AND name = 'John'",
                  'active' => "SELECT id, name FROM users WHERE active = 't' AND name = 'John'",
                  'NOT active' => "SELECT id, name FROM users WHERE active = 'f' AND name = 'John'",
                  "id = 3 AND name <> 'Fred'" => "SELECT id, name FROM users WHERE id = 3 AND name <> 'Fred' AND name = 'John'"}
    conditions.each do |cond, expect|
      @report.sql = base_sql + ' WHERE ' + cond
      params = []
      params << Dataminer::QueryParameter.new('name', Dataminer::OperatorValue.new('=', 'John'))
      @report.apply_params(params)
      assert_equal expect, @report.runnable_sql
    end
  end

  def test_find_column
    @report.sql = "SELECT id, name AS login FROM users;"
    assert_equal 'id', @report.column('id').name
    assert_equal 'login', @report.column('login').name
    assert_equal 'name', @report.column('login').namespaced_name
  end

  def test_function_not_table
    # Should take params and add between brackets - retaining any existing params.
    skip "SELECT storeopeninghours_tostring AS tmp from storeopeninghours_tostring('123');"
  end

end
