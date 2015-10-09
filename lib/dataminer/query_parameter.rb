module Dataminer

  class QueryParameter

    NULL_TEST = /NULL/i

    # FUTURE VALIDATIONS
    # date   => only type for between
    # string => only type for LIKE operators
    # bool   => can only be is/not/=/<> ; value can only be NULL, true, false
    # value  == null, operator must be is/not
    #
    # NEED data_type to validate operator/value combinations
    def initialize(namespaced_name, op_val, options={})
      @qualified_column_name = namespaced_name.is_a?(String) ? namespaced_name.split('.') : Array(namespaced_name)
      @op_val         = op_val
      @is_an_or_range = options[:is_an_or_range] || false
      @convert        = options[:convert] || :to_S
    end

    # Handle OR and multiple values... also BETWEEN, IN...

    def to_ast
      operator = @op_val.operator_for_sql
      values   = @op_val.values_for_sql

      if values.first =~ NULL_TEST
        if operator =~ /not/i
          {"NULLTEST"=>{"arg"=>{"COLUMNREF"=>{"fields"=>@qualified_column_name}}, "nulltesttype"=>1, "argisrow"=>false}}
        else
          {"NULLTEST"=>{"arg"=>{"COLUMNREF"=>{"fields"=>@qualified_column_name}}, "nulltesttype"=>0, "argisrow"=>false}}
        end
      elsif operator =~ /between/i
        {"AEXPR AND"=>{"lexpr"=>{"AEXPR"=>{"name"=>[">="], "lexpr"=>{"COLUMNREF"=>{"fields"=>@qualified_column_name}}, "rexpr"=>{"A_CONST"=>{"val"=>values[0]}}}}, "rexpr"=>{"AEXPR"=>{"name"=>["<="], "lexpr"=>{"COLUMNREF"=>{"fields"=>@qualified_column_name}}, "rexpr"=>{"A_CONST"=>{"val"=>values[1]}}}}}}
      elsif operator =~ /in/i
        val_range = values.map {|v| {"A_CONST"=>{"val"=>v}} }
        {"AEXPR IN"=>{"name"=>["="], "lexpr"=>{"COLUMNREF"=>{"fields"=>@qualified_column_name}}, "rexpr"=>val_range}}
      elsif @is_an_or_range
        or_params = values.map {|val| {"AEXPR"=>{"name"=>[operator], "lexpr"=>{"COLUMNREF"=>{"fields"=>@qualified_column_name}}, "rexpr"=>{"A_CONST"=>{"val"=>val}}}}}
        hash = {}
        join_or_params(hash, or_params)
        hash
      else
        {"AEXPR"=> {"name"=> [operator ], "lexpr"=> {"COLUMNREF"=> {"fields"=> @qualified_column_name } }, "rexpr"=> {"A_CONST"=> {"val"=>values.first } } } }
      end
    end

    # Take a string WHERE clause and create an Array of QueryParamter instances.
    def self.reverse_engineer_from_string(str)
      clauses = str.split(/[\(|\)]/).reject {|a| a == '' } # splits per bracket... then splits per OR... then splits per AND... then resolve col, op and value...
      # then create QueryParameter for each condition.
      params = []

      clauses.each do |c|
        ands = c.split(/and/i)
        ands.each do |a|
          a = a.strip
          params << make_params_from_clause(a)
        end
      end
      params
    end

    private

    # This currently handles col is null, col is not null, boolean, not boolean and col operator value.
    # TODO: handle IN (...) and OR ...
    def self.make_params_from_clause(clause)
      ar = clause.split(/\s+/)
      if ar.length == 1                       # boolean col is true  - WHERE bool_column
        ov = OperatorValue.new('=', true)
        QueryParameter.new(ar[0], ov)
      elsif ar.length == 2 && ar[0] =~ /not/i # boolean col is false - WHERE NOT bool_column
        ov = OperatorValue.new('=', false)
        QueryParameter.new(ar[1], ov)
      else
        if ar.last =~ /null/i # Handle col IS NULL / col IS NOT NULL
          if ar[-2] =~ /not/i
            op = 'not_null'
          else
            op = 'is_null'
          end
          ov = OperatorValue.new(op, 'NULL')
          QueryParameter.new(ar[0], ov)
        else # Handle col =/>/</etc value
          value = ar[2]
          if value.start_with?("'")
            value.gsub!(/\A'|'\Z/, '')
          else
            value = ar[2].to_i
          end
          ov = OperatorValue.new(ar[1], value)
          QueryParameter.new(ar[0], ov)
        end
      end
    end

    def join_or_params(hash,params)
      if params.count > 1
        hash['AEXPR OR'] = {'lexpr' => {}}
        next_part = hash['AEXPR OR']['lexpr']
        hash['AEXPR OR']['rexpr'] = params.pop
        if params.count == 1
          hash['AEXPR OR']['lexpr'] = params.pop
        else
          join_or_params(next_part, params)
        end
      else
        hash['lexpr'] = params.pop
      end
    end

  end

end
