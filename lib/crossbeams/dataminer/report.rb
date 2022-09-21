module Crossbeams
  module Dataminer
    # Dataminer Report definition.
    #
    # Create a report instance, set its SQL, define parameters, apply parameter values
    # and get the SQL to be run.
    #
    # PgQuery consts:
    # https://github.com/lfittl/pg_query/blob/master/lib/pg_query/node_types.rb
    class Report # rubocop:disable Metrics/ClassLength
      attr_accessor :columns, :limit, :offset, :caption
      attr_reader :sql, :query_parameter_definitions, :external_settings

      # Create a report.
      #
      # @param caption [String, nil] the caption for the report.
      # @return self.
      def initialize(caption = nil)
        @limit                       = nil
        @offset                      = nil
        @columns                     = {}
        @sql                         = nil
        @order                       = []
        @query_parameter_definitions = []
        @caption                     = caption
        @modified_parse              = nil
        @external_settings           = {}
      end

      # QueryParameterDefinitions in order of UI priority, then caption
      #
      # @return [Array<QueryParameterDefinition>]
      def ordered_query_parameter_definitions
        query_parameter_definitions.sort_by { |q| [q.ui_priority, q.caption] }
      end

      # Get the report's columns in sequence number order.
      #
      # @return [Array<Column>] the columns ordered by sequence number.
      def ordered_columns
        @columns.map { |_, v| v }.sort_by(&:sequence_no)
      end

      # Set the SQL of the report.
      # This will validate the SQL and build the columns list.
      #
      # @param value [String] the SQL query.
      # @return void.
      def sql=(value)
        @current_columns = @columns.dup
        @columns.clear
        @applied_params = []

        @parsed_sql     = PgQuery.parse(value)
        @modified_parse = nil

        assert_select_query!

        create_and_validate_columns

        validate_select_star!

        @limit  = limit_from_sql
        @offset = offset_from_sql
        @order  = original_select.sort_clause
        @sql    = value.chomp
      rescue PgQuery::ParseError => e
        raise SyntaxError, e.message
      end

      # Replace the ORDER BY clause.
      #
      # @param value [String] the ORDER BY clause.
      # @return void.
      def order_by=(value)
        if value.nil? || value == ''
          @order = []
        else
          sql      = "SELECT 1 ORDER BY #{value}"
          pg_order = PgQuery.parse(sql)
          @order   = tree_select_stmt(pg_order.tree).sort_clause
        end
      end

      # The list of tables referenced in the query.
      #
      # @return [Array<String>] the list of tables.
      def tables
        raise Error, 'SQL string has not yet been set' if @sql.nil?

        @parsed_sql.tables
      end

      # The list of tables (or aliases when applicable) referenced in the query.
      #
      # @return [Array<String>] the list of tables or aliases.
      def tables_or_aliases
        raise Error, 'SQL string has not yet been set' if @sql.nil?

        @parsed_sql.aliases.keys + (tables - @parsed_sql.aliases.values)
      end

      # Replace the where clause with a new one.
      #
      # @param params {Array<QueryParameter>] an array of QueryParameters.
      # @return void.
      def replace_where(params)
        @modified_parse = @parsed_sql.dup
        modified_select.where_clause = nil
        apply_params(params, prepared_tree: true)
      end

      # Take a list of QueryParameter and apply the values to the query's WHERE clause.
      # Apply the +limit+ and +offset+ attributes to the query.
      #
      # @param params [Array<QueryParameter>] the query parameters to apply.
      # @param [Hash] opts the options for applying parameters.
      # @option opts [Boolean] :prepared_tree Has the parsetree been prepared - true or false.
      # @return void.
      def apply_params(params, opts = {})
        # TODO: params could be a param set.. should be wrapped in brackets...
        @modified_parse = @parsed_sql.dup unless opts[:prepared_tree]

        apply_limit
        apply_offset

        @applied_params = params
        return if params.empty?

        string_params = params.map(&:to_string)

        if modified_select.where_clause.nil?
          apply_params_without_where_clause(string_params)
        else
          apply_params_with_where_clause(string_params)
        end
      end

      # Extract the LIMIT value from the SQL.
      #
      # @return limit [Integer]
      def limit_from_sql
        limit_clause = original_select.limit_option == :LIMIT_OPTION_DEFAULT ? nil : original_select&.limit_count
        return nil if limit_clause.nil?

        get_int_value(limit_clause)
      end

      # Take the limit attribute and apply it to the SQL.
      #
      # @return void.
      def apply_limit
        if @limit.nil? || @limit.zero?
          modified_select.limit_option = :LIMIT_OPTION_DEFAULT
          modified_select.limit_count = nil
        else
          modified_select.limit_option = :LIMIT_OPTION_COUNT
          modified_select.limit_count = make_int_value_node(@limit)
        end
      end

      # Extract the OFFSET value from the SQL.
      #
      # @return offset [Integer]
      def offset_from_sql
        offset_clause = original_select.limit_option == :LIMIT_OPTION_DEFAULT ? nil : original_select&.limit_offset
        return nil if offset_clause.nil?

        get_int_value(offset_clause)
      end

      # Take the offset attribute and apply it to the SQL.
      #
      # @return void.
      def apply_offset
        if @offset.nil? || @offset.zero?
          modified_select.limit_offset = nil
          modified_select.limit_option = :LIMIT_OPTION_DEFAULT if @limit.nil? || @limit.zero?
        else
          modified_select.limit_option = :LIMIT_OPTION_COUNT
          modified_select.limit_offset = make_int_value_node(@offset)
        end
      end

      # Take the order attribute and apply it to the SQL's ORDER BY clause.
      #
      # @return void.
      def apply_order
        modified_select.sort_clause = @order
      end

      # The applied parameters as an array of strings.
      #
      # @return [Array<String>] the chosen parameter descriptions.
      def parameter_texts
        @applied_params.map(&:to_text)
      end

      # Display the PgQuery's parsetree.
      #
      # @return [String] the parsetree.
      def show_tree
        (@modified_parse || @parsed_sql).tree.stmts[0].inspect
      end

      # The SQL with parameters applied so that it can be run against a database.
      #
      # @return [String] the SQL to run.
      def runnable_sql
        @modified_parse ||= @parsed_sql
        apply_order
        (@modified_parse || @parsed_sql).deparse # nil, :sql || nil, mssql
      end

      # The SQL with parameters applied so that it can be run against a database.
      # Changes the delimiters for MS SQL Server to avoid problems with double-quoted identifiers.
      #
      # @param delimiters [Symbol] the type of delimiters to use. Can be :sql (default) or :mssql.
      # @return [String] the SQL to run.
      def runnable_sql_delimited(delimiters = :sql)
        return runnable_sql if delimiters != :mssql
        raise SyntaxError, 'OFFSET clause is not available for MSSQL queries' if offset_from_sql

        limit = limit_from_sql
        sql = limit.nil? ? runnable_sql : convert_limit_to_top(runnable_sql, limit)
        sql.tr('"', '')
      end

      # Take the report's SQL and create a COUNT(*) query based on the same TABLE/FROM/JOINS/WHERE
      #
      # @return [String] runnable SQL COUNT query
      def count_query # rubocop:disable Metrics/AbcSize
        parsed_count = [PgQuery::Node.from(PgQuery::ResTarget.new(val: PgQuery::Node.from(PgQuery::FuncCall.new(funcname: [PgQuery::Node.from(PgQuery::String.new(str: 'count'))], agg_star: true))))]
        parse = PgQuery.parse(runnable_sql)
        tree = tree_select_stmt(parse.tree)
        tree.limit_option = :LIMIT_OPTION_DEFAULT
        tree.limit_count = nil
        tree.limit_offset = nil
        tree.sort_clause&.replace([])
        tree.target_list.replace(parsed_count)
        parse.deparse
      end

      # Get a column by its +name+.
      #
      # @param name [String] the column name.
      # @return [Column] the column with matching name.
      def column(name)
        @columns[name]
      end

      # Find a QueryParameterDefinition for a specified Column.
      #
      # @param column [Column] the column.
      # @return [QueryParameterDefinition] the parameter definition.
      def parameter_definition(column)
        @query_parameter_definitions.find { |param| param.column == column }
      end

      # Get a persistable Hash representation of the report.
      #
      # @return [Hash] the definition of the report and parameters.
      def to_hash
        hash = {}
        %i[caption sql limit offset external_settings].each { |k| hash[k] = send(k) }
        hash[:columns] = {}
        columns.each { |name, col| hash[:columns][name] = col.to_hash }
        hash[:query_parameter_definitions] = query_parameter_definitions.map(&:to_hash)
        hash
      end

      # Apply modifications in a Hash to the report.
      #
      # @param hash [Hash] the modified hash.
      # @return self the report.
      def update_from_hash(hash)
        @caption = hash[:caption]
        self.sql = hash[:sql]

        @limit   = hash[:limit]
        @offset  = hash[:offset]
        ext_set  = hash.fetch(:external_settings, {})
        raise Error, 'External settings must be a hash' unless ext_set.is_a?(Hash)

        @external_settings = ext_set

        update_columns_from_hash(hash)
        update_query_parameter_definitions_from_hash(hash)

        self
      end

      # Create a Report from a Hash.
      #
      # @param hash [Hash] the report as a hash.
      # @return self the new report.
      def self.create_from_hash(hash)
        report = new
        report.update_from_hash(hash)
      end

      # Pass a hash representation of the report to a Persistor to save it.
      #
      # @param persistor [YamlPersistor] the persistor.
      # @return void.
      def save(persistor)
        persistor.save(to_hash)
      end

      # Create a report from a Persistor.
      #
      # @param persistor [YamlPersistor] the persistor.
      # @return [Report] a report.
      def self.load(persistor)
        create_from_hash(persistor.to_hash)
      end

      # Add a QueryParameterDefinition to the report.
      #
      # @param param_def [QueryParameterDefinition] the parameter definition.
      # @return void.
      def add_parameter_definition(param_def)
        raise ArgumentError, 'Duplicate parameter definition' if query_parameter_definitions.any? { |other| param_def == other }

        query_parameter_definitions << param_def
      end

      # Remove columns from the query's SELECT, GROUP BY and ORDER BY clauses.
      #
      # @param column_keys [String, Array<String>] the name(s) of the column(s) to remove.
      # @return void.
      def remove_columns(column_keys)
        columns = Array(column_keys)

        columns.each do |column_key|
          remove_column(@columns[column_key])
          remove_sorted_column(@columns[column_key])
          remove_grouped_column(@columns[column_key])
        end
      end

      # Convert a list of columns into an Array with a new name.
      #
      # @example
      #   SQL: SELECT id, name, surname, email, address FROM users;
      #   convert_columns_to_array('user_detail', ['name', 'surname', 'email'])
      #   SQL: SELECT id, ARRAY[name, surname, email] AS user_detail, address FROM users;
      #
      # @param new_name [String] the alias for the new array column.
      # @param column_keys [Array<String>] the columns to convert into an array column.
      # @return void.
      def convert_columns_to_array(new_name, column_keys)
        columns = column_keys.map { |k| @columns[k] }
        array_select = "ARRAY[\"#{columns.map(&:namespaced_name).join('", "')}\"] AS #{new_name}"

        columns.each do |column|
          remove_column(column)
        end

        ar_tree = array_tree_for(new_name, array_select)
        original_select.target_list.unshift(ar_tree)
      end

      private

      def convert_limit_to_top(runnable_sql, limit)
        sql = runnable_sql.sub(/ limit #{limit}/i, '')
        sql.sub(/select /i, "SELECT TOP #{limit} ")
      end

      def tree_select_stmt(tree)
        tree.stmts[0].stmt.select_stmt

        # -------------------------------------------------------------------------
        # BELOW attempt to handle UNION queries, but this breaks down elsewhere, so
        # the whole deparse and re-assemble would need to be redesigned...
        # THEREFORE: Do not use union queries in DM reports.
        # -------------------------------------------------------------------------

        # sel = tree[0][PgQuery::RAW_STMT][PgQuery::STMT_FIELD][PgQuery::SELECT_STMT]
        # return sel if sel.nil?
        # return sel unless sel['larg']
        #
        # # UNION query, take just the first select
        # sel['larg'][PgQuery::SELECT_STMT]
      end

      def array_tree_for(new_name, array_select)
        pg_temp = PgQuery.parse("SELECT #{array_select} FROM temp")
        # tree_select_stmt(pg_temp.tree)[PgQuery::TARGET_LIST_FIELD].select { |a| a['ResTarget']['name'] == new_name }.first
        tree_select_stmt(pg_temp.tree).target_list.select { |a| a.res_target.name == new_name }.first
      end

      def remove_column(column)
        original_select.target_list.reject! do |col|
          col.res_target == column.parse_path
        end
      end

      def remove_sorted_column(column)
        original_select.sort_clause.reject! do |order|
          order.sort_by.node.column_ref.fields.map { |f| f.string.str }.join('.') == column.namespaced_name
        end
      end

      def remove_grouped_column(column)
        original_select.group_clause.reject! do |group|
          group.column_ref.fields.map { |f| f.string.str }.join('.') == column.namespaced_name
        end
      end

      def original_select
        tree_select_stmt(@parsed_sql.tree)
      end

      def modified_select
        tree_select_stmt(@modified_parse.tree)
      end

      def assert_select_query!
        raise ArgumentError, 'Only SELECT is allowed' if original_select.nil?
      end

      def create_and_validate_columns
        original_select.target_list.each_with_index do |target, index|
          col = Column.create_from_parse(index + 1, target.res_target)
          raise ArgumentError, %(SQL has duplicate columns with name: "#{col.name}") unless @columns[col.name].nil?

          previous_column = @current_columns[col.name]
          @columns[col.name] = col.update_from(previous_column)
        end
      end

      def validate_select_star!
        # one of the columns is "*"...
        raise ArgumentError, 'Cannot have * as a column selector' if @columns.keys.any? { |a| a == 'pgq_a_star' }
      end

      def make_int_value_node(int)
        PgQuery::Node.from(PgQuery::A_Const.new(val: PgQuery::Node.from(PgQuery::Integer.new(ival: int))))
      end

      def get_int_value(node)
        node.a_const.val.integer.ival
      end

      def apply_params_without_where_clause(string_params)
        sql = 'SELECT 1 WHERE ' << string_params.join(' AND ')
        pg_where = PgQuery.parse(sql)
        modified_select.where_clause = tree_select_stmt(pg_where.tree).where_clause
      end

      def apply_params_with_where_clause(string_params)
        pg_where     = plain_sql_loaded_with_current_where
        pg_new_where = PgQuery.parse("#{pg_where.deparse} AND #{string_params.join(' AND ')}")
        modified_select.where_clause = tree_select_stmt(pg_new_where.tree).where_clause
      end

      def plain_sql_loaded_with_current_where
        pg_where = PgQuery.parse('SELECT 1')
        tree_select_stmt(pg_where.tree).where_clause = modified_select.where_clause
        pg_where
      end

      def update_columns_from_hash(hash)
        hash[:columns].each { |name, column| @columns[name].modify_from_hash(column) }
      end

      def update_query_parameter_definitions_from_hash(hash)
        @query_parameter_definitions = []
        hash[:query_parameter_definitions].each { |qpd| @query_parameter_definitions << QueryParameterDefinition.create_from_hash(qpd) }
      end
    end
  end
end
