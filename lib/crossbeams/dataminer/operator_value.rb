module Crossbeams
  module Dataminer
    class OperatorValue # rubocop:disable Metrics/ClassLength
      attr_accessor :data_type
      attr_reader :values

      VALID_OPERATORS = %w[= >= <= <> > < between starts_with ends_with contains in in_or_null is_null not_null match_or_null].freeze

      OPERATORS = {
        '=' => 'equals',
        '>=' => 'greater than or equal to',
        '<=' => 'less than or equal to',
        '<>' => 'not equal to',
        '>' => 'greater than',
        '<' => 'less than',
        'between' => 'between',
        'starts_with' => 'starts with',
        'ends_with' => 'ends with',
        'contains' => 'contains',
        'in' => 'is any of',
        'in_or_null' => 'is any of or is blank',
        'match_or_null' => 'is equal to or blank',
        'is_null' => 'is blank',
        'not_null' => 'is not blank'
      }.freeze

      def initialize(operator, values = nil, data_type = nil)
        @operator  = operator.downcase
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

      def operator_for_text
        OPERATORS[@operator]
      end

      def check_for_valid_operator_value_combination
        err_msg = case @operator
                  when 'between'
                    check_between_values
                  when 'in'
                    check_in_values
                  when 'is_null', 'not_null'
                    nil
                  else
                    check_other_values
                  end
        raise ArgumentError, err_msg unless err_msg.nil?
      end

      def values_for_sql
        @values.map do |value|
          case value
          when true
            "'t'"
          when false
            "'f'"
          else
            sql_value_from_operator(value)
          end
        end
      end

      private

      def check_between_values
        if @values.count < 2 || @values.any? { |v| v.nil? || v.is_a?(String) && v.empty? }
          'Must have from and to values for BETWEEN operator'
        elsif @values[0] > @values[1]
          'End of date range cannot be less than start of range for BETWEEN operator'
        end
      end

      def check_in_values
        'Must have range of values for IN operator' if @values.length.positive? && @values.first.nil?
      end

      def check_other_values
        'Parameter must have a value' if @values.first.nil? && @operator != 'in_or_null'  # TODO: Maybe need to be able to say "... WHERE xyz <> ''; " ????
      end

      def sql_value_from_operator(value)
        case @operator
        when 'starts_with'
          "'#{value.to_s.gsub("'", "''")}%'"
        when 'ends_with'
          "'%#{value.to_s.gsub("'", "''")}'"
        when 'contains'
          "'%#{value.to_s.gsub("'", "''")}%'"
        when 'not_null', 'is_null'
          'NULL'
        else
          sql_value_from_data_type(value)
        end
      end

      def sql_value_from_data_type(value)
        case @data_type
        when :integer
          value.to_i
        when :number
          value.to_f
        else
          "'#{value.to_s.gsub("'", "''")}'"
        end
      end
    end
  end
end
