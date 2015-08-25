module Dataminer

  class Report
    attr_accessor :sql, :columns

    def sql=(value)
      @parsed_sql = PgQuery.parse(value)
      # @columns = @parsed_sql.parsetree[0]['SELECT']['targetList'].map {|r| get_column_name(r['RESTARGET']) }
      @columns = []
      @parsed_sql.parsetree[0]['SELECT']['targetList'].each_with_index {|t,i| @columns << Column.create_from_parse(i+1, t['RESTARGET']) }
      # if @columns.include?('A_STAR') # one of the columns is "*"...
      if @columns.any? {|a| a.name.include?('A_STAR') } # one of the columns is "*"...
      #if @parsed_sql.parsetree[0]['SELECT']['targetList'][0]['RESTARGET']['val']['COLUMNREF']['fields'].any? {|f| f.is_a?(Hash) && f.keys.include?('A_STAR') }
        raise ArgumentError, 'Cannot have * as a column selector'
      end
      @sql = value

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
      return if params.length == 0

      # How to merge params if existing?
      if @modified_parse.parsetree[0]['SELECT']['whereClause'].nil?
        if params.length == 1
          @modified_parse.parsetree[0]['SELECT']['whereClause'] = params.first.to_ast
        else
          @modified_parse.parsetree[0]['SELECT']['whereClause'] = combine_params_for_where(params)
        end
      else
        curr_where = @modified_parse.parsetree[0]['SELECT']['whereClause'].dup
        exist_where = @parsed_sql.deparse([curr_where])
        plus_parms = QueryParameter.reverse_engineer_from_string(exist_where)
        @modified_parse.parsetree[0]['SELECT']['whereClause'] = combine_params_for_where(plus_parms + params)
      end
    end

    def show_tree
      puts @modified_parse.parsetree[0].inspect
    end

    def runnable_sql
      (@modified_parse || @parsed_sql).deparse
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
