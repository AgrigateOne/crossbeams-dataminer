# rubocop:disable Metrics/ClassLength
module Crossbeams
  module Dataminer
    # PgQuery consts:
    # https://github.com/lfittl/pg_query/blob/master/lib/pg_query/node_types.rb
    class Report
      attr_accessor :sql, :columns, :limit, :offset, :caption # name?...
      attr_reader :query_parameter_definitions

      def initialize(caption = nil)
        @limit                       = nil
        @offset                      = nil
        @columns                     = {}
        @sql                         = nil
        @order                       = nil
        @query_parameter_definitions = []
        @caption                     = caption
        @modified_parse              = nil
      end

      def ordered_columns
        @columns.map { |_, v| v }.sort_by(&:sequence_no)
      end

      def sql=(value)
        @columns.clear
        column_names = []

        @parsed_sql = PgQuery.parse(value)
        validate_is_select!

        original_select[PgQuery::TARGET_LIST_FIELD].each_with_index do |target, index|
          col                = Column.create_from_parse(index + 1, target[PgQuery::RES_TARGET])
          @columns[col.name] = col
          column_names << col.name
        end

        if @columns.keys.any? { |a| a.include?(PgQuery::A_STAR) } # one of the columns is "*"...
          raise ArgumentError, 'Cannot have * as a column selector'
        end

        raise ArgumentError, 'SQL has duplicate column names' unless column_names.length == column_names.uniq.length

        @limit  = limit_from_sql
        @offset = offset_from_sql
        @order  = original_select['sortClause']
        @sql    = value

        # TODO: maybe do a quick deparse and raise exception on failure if SQL cannot be deparsed....

      rescue PgQuery::ParseError => e
        raise SyntaxError, e.message
      end

      def order_by=(value)
        if value.nil? || '' == value
          @order = nil
        else
          sql      = "SELECT 1 ORDER BY #{value}"
          pg_order = PgQuery.parse(sql)
          @order   = pg_order.tree[0][PgQuery::SELECT_STMT]['sortClause']
        end
      end

      def tables
        raise 'SQL string has not yet been set' if @sql.nil?
        @parsed_sql.tables
      end

      def replace_where(params)
        @modified_parse = @parsed_sql.dup
        modified_select['whereClause'] = nil
        apply_params(params, prepared_tree: true)
      end

      # TODO: params could be a param set.. should be wrapped in brackets...
      def apply_params(params, options = {})
        @modified_parse = @parsed_sql.dup unless options[:prepared_tree]

        apply_limit
        apply_offset

        return if params.empty?

        string_params = params.map(&:to_string)

        if modified_select['whereClause'].nil?
          apply_params_without_where_clause(string_params)
        else
          apply_params_with_where_clause(string_params)
        end
      end

      def limit_from_sql
        limit_clause = original_select['limitCount']
        return nil if limit_clause.nil?

        get_int_value(limit_clause)
      end

      def apply_limit
        modified_select['limitCount'] = if @limit.nil? || @limit.zero?
                                          nil
                                        else
                                          make_int_value_hash(@limit)
                                        end
      end

      def offset_from_sql
        offset_clause = original_select['limitOffset']
        return nil if offset_clause.nil?

        get_int_value(offset_clause)
      end

      def apply_offset
        modified_select['limitOffset'] = if @offset.nil? || @offset.zero?
                                           nil
                                         else
                                           make_int_value_hash(@offset)
                                         end
      end

      def apply_order
        modified_select['sortClause'] = @order
      end

      def show_tree
        @modified_parse.tree[0].inspect
      end

      def runnable_sql
        @modified_parse ||= @parsed_sql
        apply_order
        # NOTE: The gsub is here because of the way PgQuery deparses char varying without a specified limit:
        #       -- CAST(x AS character varying)
        #       -> x:varchar()
        (@modified_parse || @parsed_sql).deparse.gsub('varchar()', 'varchar')
      end

      def column(name)
        @columns[name]
      end

      def parameter_definition(column)
        @query_parameter_definitions.find { |param| param.column == column }
      end

      def to_hash
        hash = {}
        [:caption, :sql, :limit, :offset].each { |k| hash[k] = send(k) }
        hash[:columns] = {}
        columns.each { |name, col| hash[:columns][name] = col.to_hash }
        hash[:query_parameter_definitions] = query_parameter_definitions.map(&:to_hash)
        hash
      end

      def update_from_hash(hash)
        @caption = hash[:caption]
        self.sql = hash[:sql]

        @limit   = hash[:limit]
        @offset  = hash[:offset]

        hash[:columns].each { |name, column| @columns[name].modify_from_hash(column) }

        @query_parameter_definitions = []
        hash[:query_parameter_definitions].each { |qpd| @query_parameter_definitions << QueryParameterDefinition.create_from_hash(qpd) }

        self
      end

      def self.create_from_hash(hash)
        report = new
        report.update_from_hash(hash)
      end

      def save(persistor)
        persistor.save(to_hash)
      end

      def self.load(persistor)
        create_from_hash(persistor.to_hash)
      end

      def add_parameter_definition(param_def)
        raise ArgumentError, 'Duplicate parameter definition' if query_parameter_definitions.any? { |other| param_def == other }
        query_parameter_definitions << param_def
      end

      private

      def original_select
        @parsed_sql.tree[0][PgQuery::SELECT_STMT]
      end

      def modified_select
        @modified_parse.tree[0][PgQuery::SELECT_STMT]
      end

      def validate_is_select!
        raise ArgumentError, 'Only SELECT is allowed' if original_select.nil?
      end

      def make_int_value_hash(int)
        { PgQuery::A_CONST => { 'val' => { PgQuery::INTEGER => { 'ival' => int } } } }
      end

      def get_int_value(hash)
        hash[PgQuery::A_CONST]['val'][PgQuery::INTEGER]['ival']
      end

      def apply_params_without_where_clause(string_params)
        sql = 'SELECT 1 WHERE ' << string_params.join(' AND ')
        pg_where = PgQuery.parse(sql)
        modified_select['whereClause'] = pg_where.tree[0][PgQuery::SELECT_STMT]['whereClause']
      end

      def apply_params_with_where_clause(string_params)
        pg_where     = plain_sql_loaded_with_current_where
        pg_new_where = PgQuery.parse(pg_where.deparse + ' AND ' + string_params.join(' AND '))
        modified_select['whereClause'] = pg_new_where.tree[0][PgQuery::SELECT_STMT]['whereClause']
      end

      def plain_sql_loaded_with_current_where
        pg_where = PgQuery.parse('SELECT 1')
        pg_where.tree[0][PgQuery::SELECT_STMT]['whereClause'] = modified_select['whereClause']
        pg_where
      end
    end
  end
end
