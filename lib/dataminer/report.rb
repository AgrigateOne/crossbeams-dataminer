module Dataminer

  class Report
    attr_accessor :sql, :columns, :limit, :offset, :caption #name?...
    attr_reader :query_parameter_definitions

    def initialize(caption=nil)
      @limit                       = nil
      @offset                      = nil
      @columns                     = {}
      @sql                         = nil
      @query_parameter_definitions = []
      @caption                     = caption
    end

    def ordered_columns
      @columns.map {|k,v| v }.sort_by {|a| a.sequence_no }
    end

    def sql=(value)
      @columns.clear
      column_names = []

      @parsed_sql = PgQuery.parse(value)
      @parsed_sql.parsetree[0]['SELECT']['targetList'].each_with_index do |t,i|
        col = Column.create_from_parse(i+1, t['RESTARGET'])
        @columns[col.name] = col
        column_names << col.name
      end

      if @columns.keys.any? {|a| a.include?('A_STAR') } # one of the columns is "*"...
        raise ArgumentError, 'Cannot have * as a column selector'
      end

      raise ArgumentError, 'SQL has duplicate column names' unless column_names.length == column_names.uniq.length

      @limit  = limit_from_sql
      @offset = offset_from_sql
      @sql    = value

    rescue PgQuery::ParseError => e
      raise SyntaxError, e.message
    end

    def replace_where(params)
      @modified_parse = @parsed_sql.dup
      @modified_parse.parsetree[0]['SELECT']['whereClause'] = nil
      apply_params(params, :prepared_parsetree => true)
    end

    # This should be changed to allow for the case where some parameters are already in place...
    def apply_params(params, options={})
      @modified_parse = @parsed_sql.dup unless options[:prepared_parsetree]

      apply_limit
      apply_offset

      return if params.length == 0

      # How to merge params if existing?
      if @modified_parse.parsetree[0]['SELECT']['whereClause'].nil?
        if params.length == 1
          @modified_parse.parsetree[0]['SELECT']['whereClause'] = params.first.to_ast
        else
          @modified_parse.parsetree[0]['SELECT']['whereClause'] = combine_params_for_where(params)
        end
      else
        curr_where  = @modified_parse.parsetree[0]['SELECT']['whereClause'].dup
        exist_where = @parsed_sql.deparse([curr_where])
        plus_parms  = QueryParameter.reverse_engineer_from_string(exist_where)
        @modified_parse.parsetree[0]['SELECT']['whereClause'] = combine_params_for_where(plus_parms + params)
      end
    end

    def limit_from_sql
      limit_clause = @parsed_sql.parsetree[0]['SELECT']['limitCount']
      return nil if limit_clause.nil?

      limit_clause["A_CONST"]["val"]
    end

    def apply_limit
      if @limit.nil? || @limit.zero?
        @modified_parse.parsetree[0]['SELECT']['limitCount'] = nil
      else
        @modified_parse.parsetree[0]['SELECT']['limitCount'] = {"A_CONST"=>{"val"=>@limit}}
      end
    end

    def offset_from_sql
      offset_clause = @parsed_sql.parsetree[0]['SELECT']['limitOffset']
      return nil if offset_clause.nil?

      offset_clause["A_CONST"]["val"]
    end

    def apply_offset
      if @offset.nil? || @offset.zero?
        @modified_parse.parsetree[0]['SELECT']['limitOffset'] = nil
      else
        @modified_parse.parsetree[0]['SELECT']['limitOffset'] = {"A_CONST"=>{"val"=>@offset}}
      end
    end

    def show_tree
      @modified_parse.parsetree[0].inspect
    end

    def runnable_sql
      (@modified_parse || @parsed_sql).deparse
    end

    def column(name)
      @columns[name]
    end

    def to_hash
      hash = {}
      [:caption, :sql,:limit, :offset].each {|k| hash[k] = self.send(k) }
      hash[:columns] = {}
      columns.each {|name, col| hash[:columns][name] = col.to_hash }
      hash[:query_parameter_definitions] = query_parameter_definitions.map {|q| q.to_hash }
      hash
    end

    def update_from_hash(hash)
      @caption = hash[:caption]
      self.sql = hash[:sql]

      @limit   = hash[:limit]
      @offset  = hash[:offset]

      hash[:columns].each {|name, column| @columns[name].modify_from_hash(column) }

      @query_parameter_definitions = []
      hash[:query_parameter_definitions].each {|qpd| @query_parameter_definitions << QueryParameterDefinition.create_from_hash(qpd) }

      self
    end

    def self.create_from_hash(hash)
      new = self.new
      new.update_from_hash(hash)
    end

    def save(persistor)
      persistor.save(self.to_hash)
    end

    def self.load(persistor)
      self.create_from_hash(persistor.to_hash)
    end

    def add_parameter_definition(param_def)
      raise ArgumentError, 'Duplicate parameter definition' if query_parameter_definitions.any? {|other| param_def == other }
      query_parameter_definitions << param_def
    end

    private

    def combine_params_for_where(params)
      hash = {}
      join_add_params(hash, params)
      hash
    end

    def join_add_params(hash,params)
      if params.count > 1
        hash['AEXPR AND'] = {'lexpr' => {}}
        next_part = hash['AEXPR AND']['lexpr']
        hash['AEXPR AND']['rexpr'] = params.pop.to_ast
        if params.count == 1
          hash['AEXPR AND']['lexpr'] = params.pop.to_ast
        else
          join_add_params(next_part, params)
        end
      else
        hash['lexpr'] = params.pop.to_ast
      end
    end

    def combine_params_for_where_at_right(params)
      hash = {}
      join_add_params_at_right(hash, params)
      hash
    end

    def join_add_params_at_right(hash,params)
      if params.count > 1
        hash['AEXPR AND'] = {'lexpr' => {}}
        next_part = hash['AEXPR AND']['lexpr']
        hash['AEXPR AND']['rexpr'] = params.pop.to_ast
        if params.count == 1
          hash['AEXPR AND']['lexpr'] = params.pop.to_ast
        else
          join_add_params_at_right(next_part, params)
        end
      else
        hash['rexpr'] = params.pop.to_ast
      end
    end

  end

end
