require 'test_helper'

class ColumnTest < Minitest::Test

  BASIC_COLUMN = PgQuery::ResTarget.new(val:
                                        PgQuery::Node.from(PgQuery::ColumnRef.new(fields: [PgQuery::Node.from(PgQuery::String.new(str: 'b')),
                                                                                           PgQuery::Node.from(PgQuery::String.new(str: 'name'))])))

  def test_column_caption
    column = Crossbeams::Dataminer::Column.new(1, BASIC_COLUMN)
    assert_equal 'Name', column.caption
  end

  def test_column_namespace_name_no_alias
    pg_col = PgQuery::ResTarget.new(val: PgQuery::Node.from(PgQuery::ColumnRef.new(fields: [PgQuery::Node.from(PgQuery::String.new(str: 'name'))])))
    column = Crossbeams::Dataminer::Column.new(1, pg_col)
    assert_equal 'name', column.namespaced_name
  end

  def test_column_namespace_name
    column = Crossbeams::Dataminer::Column.new(1, BASIC_COLUMN)
    assert_equal 'b.name', column.namespaced_name
  end

  def test_column_override_caption
    pg_col = first_col("SELECT b.name AS surname FROM users b")
    column = Crossbeams::Dataminer::Column.new(1, pg_col)
    assert_equal 'Surname', column.caption
  end

  def test_column_override_name
    pg_col = first_col("SELECT b.name AS surname FROM users b")
    column = Crossbeams::Dataminer::Column.new(1, pg_col)
    assert_equal 'surname', column.name
  end

  def test_column_override_namespace_name
    pg_col = first_col("SELECT b.name AS surname FROM users b")
    column = Crossbeams::Dataminer::Column.new(1, pg_col)
    assert_equal 'b.name', column.namespaced_name
  end

  def test_column_function_name
    pg_col = first_col("SELECT to_char(ps.created_at, 'IYYY--IW'::text) AS packed_week FROM tabs")
    column = Crossbeams::Dataminer::Column.new(1, pg_col)
    assert_equal 'packed_week', column.name
  end


  def test_column_function_namespace_name
    pg_col = first_col("SELECT to_char(ps.created_at, 'IYYY--IW'::text) AS packed_week FROM tabs")
    column = Crossbeams::Dataminer::Column.new(1, pg_col)
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

  def first_col(qry)
    tree = PgQuery.parse(qry).tree
    tree.stmts[0].stmt.select_stmt.target_list.first.res_target
  end

  def test_case_values
    tests = [
      [%w[one two], "SELECT CASE WHEN active THEN 'one' WHEN no = 1 THEN 'two' ELSE NULL END AS col"],
      [%w[one two def], "SELECT CASE WHEN active THEN 'one' WHEN no = 1 THEN 'two' ELSE 'def' END AS col"],
      [%w[one two def], "SELECT CASE WHEN active THEN 'one' WHEN no = 1 THEN 'two' ELSE CASE WHEN passed THEN 'def' ELSE NULL END END AS col"],
      [%w[one two], "SELECT CASE WHEN active THEN 'one' WHEN no = 1 THEN 'two' WHEN no = 3 THEN 'one' END AS col"],
      [%w[one two], "SELECT CASE WHEN act THEN CASE WHEN a = 1 THEN 'one' WHEN b = 1 THEN 'two' END WHEN d = 3 THEN 'one' END AS col"],
      [%w[one two three], "SELECT CASE WHEN act THEN CASE WHEN a = 1 THEN 'one' WHEN b = 1 THEN 'two' END WHEN d = 3 THEN 'three' END AS col"],
      [[], "SELECT col"]
    ]
    tests.each do |expect, qry|
      raw_col = first_col(qry)
      column = Crossbeams::Dataminer::Column.new(1, raw_col)
      assert_equal expect, column.case_string_values
    end
  end
end
