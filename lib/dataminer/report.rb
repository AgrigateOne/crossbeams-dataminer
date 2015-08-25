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

    def replace_where(conditions)
      @modified_parse = @parsed_sql.dup
      @modified_parse.parsetree[0]['SELECT']['whereClause'] =
 #{"AEXPR"=> {"name"=> ["=" ], "lexpr"=> {"COLUMNREF"=> {"fields"=> ["id" ], "location"=>nil } }, "rexpr"=> {"A_CONST"=> {"val"=>21, "location"=>nil } }, "location"=>nil } }
 {"AEXPR"=> {"name"=> ["=" ], "lexpr"=> {"COLUMNREF"=> {"fields"=> ["id" ] } }, "rexpr"=> {"A_CONST"=> {"val"=>21 } } } }

    end
# {"AEXPR"=> {"name"=> ["=" ], "lexpr"=> {"COLUMNREF"=> {"fields"=> ["id" ], "location"=>27 } }, "rexpr"=> {"A_CONST"=> {"val"=>21, "location"=>32 } }, "location"=>30 } }

    # This should be changed to allow for the case where some parameters are already in place...
    def apply_params(params)
      @modified_parse = @parsed_sql.dup
      if params.length == 1
        @modified_parse.parsetree[0]['SELECT']['whereClause'] = params.first.to_ast
      else
        @modified_parse.parsetree[0]['SELECT']['whereClause'] = combine_params_for_where(params)
      end
 #{"AEXPR"=> {"name"=> ["=" ], "lexpr"=> {"COLUMNREF"=> {"fields"=> ["id" ], "location"=>nil } }, "rexpr"=> {"A_CONST"=> {"val"=>21, "location"=>nil } }, "location"=>nil } }
 #{"AEXPR"=> {"name"=> ["=" ], "lexpr"=> {"COLUMNREF"=> {"fields"=> ["id" ] } }, "rexpr"=> {"A_CONST"=> {"val"=>21 } } } }
    end

    def runnable_sql
      (@modified_parse || @parsed_sql).deparse
    end

    def test(params)

    end

    private

    def combine_params_for_where(params)
      hash = {}
      add_params(hash, params)
      hash
    end

    def add_params(hash,params)
      if params.count > 1
        hash['AEXPR AND'] = {'lexpr' => {}}
        next_part = hash['AEXPR AND']['lexpr']
        hash['AEXPR AND']['rexpr'] = params.pop.to_ast
        if params.count == 1
          hash['AEXPR AND']['lexpr'] = params.pop.to_ast
        else
          add_params(next_part, params)
        end
      else
        hash['lexpr'] = params.pop.to_ast
      end
    end
 #    "whereClause"=>{"AEXPR AND"=>{"lexpr"=>{"AEXPR AND"=>{"lexpr"=>{"AEXPR AND"=>{"lexpr"=>{"AEXPR"=>{"name"=>["="], "lexpr"=>{"COLUMNREF"=>{"fields"=>["id"], "location"=>33}}, "rexpr"=>{"A_CONST"=>{"val"=>1, "location"=>38}}, "location"=>36}}, "rexpr"=>{"AEXPR"=>{"name"=>["="], "lexpr"=>{"COLUMNREF"=>{"fields"=>["name"], "location"=>45}}, "rexpr"=>{"A_CONST"=>{"val"=>"fred", "location"=>52}}, "location"=>50}}, "location"=>41}}, "rexpr"=>{"AEXPR"=>{"name"=>["="], "lexpr"=>{"COLUMNREF"=>{"fields"=>["logins"], "location"=>64}}, "rexpr"=>{"A_CONST"=>{"val"=>2, "location"=>73}}, "location"=>71}}, "location"=>60}}, "rexpr"=>{"AEXPR"=>{"name"=>["="], "lexpr"=>{"COLUMNREF"=>{"fields"=>["nn"], "location"=>80}}, "rexpr"=>{"A_CONST"=>{"val"=>"a", "location"=>85}}, "location"=>83}}, "location"=>76}},

  end

end
