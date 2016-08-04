module Dataminer

  class OperatorValue

    VALID_OPERATORS = %w{= >= <= <> > < between starts_with ends_with contains in is_null not_null}

    def initialize(operator, values=nil, data_type=nil)
      @operator  = operator
      @data_type = data_type || :string
      @values    = Array(values)

      check_for_valid_operator
      check_for_valid_operator_value_combination
    end

    def check_for_valid_operator
      raise ArgumentError, "Invalid operator - \"#{@operator}\"" unless VALID_OPERATORS.include?(@operator.downcase)
    end

    def operator_for_sql
      case @operator
      when 'starts_with', 'contains', 'ends_with'
        '~~'
      when 'not_null'
        'is not'
      when 'is_null'
        'is'
      else
        @operator
      end
    end

    def check_for_valid_operator_value_combination
      case @operator
      when 'between'
        raise ArgumentError, 'Must have from and to values for BETWEEN operator' if @values.count < 2 || @values.any? {|v| v.nil? || v.is_a?(String) && v.empty? }
        raise ArgumentError, 'End of date range cannot be less than start of range for BETWEEN operator' if @values[0] > @values[1]
      when 'in'
        raise ArgumentError, 'Must have range of values for IN operator' if @values.empty? || @values.first.nil?
      when 'is_null', 'not_null'
      else
        raise ArgumentError, 'Parameter must have a value' if @values.first.nil? #TODO Maybe need to be able to say "... WHERE xyz <> ''; " ????
      end
    end

    def values_for_sql
      @values.map do |value|
        case value
        when true
          't'
        when false
          'f'
        else
          case @operator
          when 'starts_with'
            "'#{value}%'"
          when 'ends_with'
            "'%#{value}'"
          when 'contains'
            "'%#{value}%'"
          when 'not_null', 'is_null'
            'NULL'
          else
            case @data_type
            when :integer
              value.to_i
            when :number
              value.to_f
            else
              "'#{value}'"
            end
          end
        end
      end
    end

  end

end
