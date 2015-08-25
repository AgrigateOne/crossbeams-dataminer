module Dataminer

  class QueryParameter
    attr_reader :operator
    attr_accessor :value

    NULL_VALUE      = /NULL/i
    VALID_OPERATORS = %w{= >= <= <> > < between starts_with ends_with contains is not in}

    # FUTURE VALIDATIONS
    # date   => only type for between
    # string => only type for LIKE operators
    # bool   => can only be is/not/=/<> ; value can only be NULL, true, false
    # value  == null, operator must be is/not
    #
    # NEED data_type to validate operator/value combinations
    def initialize(column_name, options={})
      @qualified_column_name = column_name.is_a?(String) ? column_name.split('.') : Array(column_name)
      @operator       = options[:operator] || '='
      check_for_valid_operator(@operator)
      @value          = options[:value]
      @from_value     = options[:from_value]
      @to_value       = options[:to_value]
      @value_range    = options[:value_range]
      @is_an_or_range = options[:is_an_or_range] || false
    end

    def operator=(value)
      check_for_valid_operator(value)
      @operator = value
    end

    def translate_expression
      if %w{starts_with contains ends_with}.include?(@operator)
        operator = '~~'
      else
        operator = @operator
      end

      value = case @value
      when true
        't'
      when false
        'f'
      else
        case @operator
        when 'starts_with'
          "#{@value}%"
        when 'ends_with'
          "%#{@value}"
        when 'contains'
          "%#{@value}%"
        else
          @value
        end
      end

      return operator, value

    end

    # Handle OR and multiple values... also BETWEEN, IN...

    def to_ast
      operator, value = translate_expression
      if value =~ NULL_VALUE
        if operator =~ /not/i
          {"NULLTEST"=>{"arg"=>{"COLUMNREF"=>{"fields"=>@qualified_column_name}}, "nulltesttype"=>1, "argisrow"=>false}}
        else
          {"NULLTEST"=>{"arg"=>{"COLUMNREF"=>{"fields"=>@qualified_column_name}}, "nulltesttype"=>0, "argisrow"=>false}}
        end
      elsif operator =~ /between/i
        {"AEXPR AND"=>{"lexpr"=>{"AEXPR"=>{"name"=>[">="], "lexpr"=>{"COLUMNREF"=>{"fields"=>@qualified_column_name}}, "rexpr"=>{"A_CONST"=>{"val"=>@from_value}}}}, "rexpr"=>{"AEXPR"=>{"name"=>["<="], "lexpr"=>{"COLUMNREF"=>{"fields"=>@qualified_column_name}}, "rexpr"=>{"A_CONST"=>{"val"=>@to_value}}}}}}
      elsif operator =~ /in/i
        values = @value_range.map {|v| {"A_CONST"=>{"val"=>v}} }
        {"AEXPR IN"=>{"name"=>["="], "lexpr"=>{"COLUMNREF"=>{"fields"=>@qualified_column_name}}, "rexpr"=>values}}
      elsif @is_an_or_range
        or_params = @value_range.map {|val| {"AEXPR"=>{"name"=>[operator], "lexpr"=>{"COLUMNREF"=>{"fields"=>@qualified_column_name}}, "rexpr"=>{"A_CONST"=>{"val"=>val}}}}}
        hash = {}
        join_or_params(hash, or_params)
        hash
      else
        {"AEXPR"=> {"name"=> [operator ], "lexpr"=> {"COLUMNREF"=> {"fields"=> @qualified_column_name } }, "rexpr"=> {"A_CONST"=> {"val"=>value } } } }
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
        QueryParameter.new(ar[0], :operator => '=', :value => true)
      elsif ar.length == 2 && ar[0] =~ /not/i # boolean col is false - WHERE NOT bool_column
        QueryParameter.new(ar[1], :operator => '=', :value => false)
      else
        if ar.last =~ /null/i # Handle col IS NULL / col IS NOT NULL
          if ar[-2] =~ /not/i
            op = 'not'
          else
            op = 'is'
          end
          QueryParameter.new(ar[0], :operator => op, :value => 'NULL')
        else # Handle col =/>/</etc value
          value = ar[2]
          if value.start_with?("'")
            value.gsub!(/\A'|'\Z/, '')
          else
            value = ar[2].to_i
          end
          QueryParameter.new(ar[0], :operator => ar[1], :value => value)
        end
      end
    end

    def check_for_valid_operator(operator)
      raise ArgumentError, "Invalid operator - \"#{operator}\"" unless VALID_OPERATORS.include?(operator.downcase)
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
