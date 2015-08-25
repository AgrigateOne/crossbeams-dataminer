module Dataminer

  class QueryParameter
    attr_reader :operator
    attr_accessor :value

    NULL_VALUE      = /NULL/i
    VALID_OPERATORS = %w{= >= <= <> > < between starts_with ends_with contains is not}

    # FUTURE VALIDATIONS
    # date => only type for between
    # string => only type for LIKE operators
    # bool => can only be is/not/=/<> ; value can only be NULL, true, false
    # value == null, operator must be is/not
    #
    # FUTURE EXTENSIONS:
    # OR... (have a parameter grouping class? - i.e. representing parentheses) [COMPOSITE] parameter sets
    # IN value range (UI can use a multiselect - also for OR...)
    #
    # NEED data_type to validate operator/value combinations
    def initialize(column_name, options={})
      @qualified_column_name = column_name.is_a?(String) ? column_name.split('.') : Array(column_name)
      @operator   = options[:operator] || '='
      check_for_valid_operator(@operator)
      @value      = options[:value]
      @from_value = options[:from_value]
      @to_value   = options[:to_value]
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
      else
        {"AEXPR"=> {"name"=> [operator ], "lexpr"=> {"COLUMNREF"=> {"fields"=> @qualified_column_name } }, "rexpr"=> {"A_CONST"=> {"val"=>value } } } }
      end
    end

    private

    def check_for_valid_operator(value)
      raise ArgumentError, "Invalid operator - \"#{value}\"" unless VALID_OPERATORS.include?(value.downcase)
    end

  end

end
