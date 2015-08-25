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
  # where clauses....

  def test_replace_where
    @report.sql = "SELECT id, name FROM users"
    @report.replace_where('id = 21')
    assert_equal "SELECT id, name FROM users WHERE id = 21", @report.runnable_sql
  end

  # def test_set_column_datatypes_from_active_record
  #   skip 'To Do...'
  # end

end
