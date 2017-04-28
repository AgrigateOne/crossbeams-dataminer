module Crossbeams
  module Dataminer
    class QueryParameter
      NULL_TEST    = /NULL/i
      NOT_TEST     = /NOT/i
      BETWEEN_TEST = /BETWEEN/i
      IN_TEST      = /IN/i

      def initialize(namespaced_name, op_val, options = {})
        @qualified_column_name = namespaced_name
        @op_val         = op_val
        @is_an_or_range = options[:is_an_or_range] || false
        @convert        = options[:convert] || :to_s
      end

      NOT_NULL_TEST = { true => 'IS NOT NULL', false => 'IS NULL' }.freeze
      def to_string
        operator = @op_val.operator_for_sql
        values   = @op_val.values_for_sql

        if values.first.to_s.match?(NULL_TEST)
          op_type = operator.match?(NOT_TEST) ? true : false
          "#{@qualified_column_name} #{NOT_NULL_TEST[op_type]}"
        else
          case operator
          when BETWEEN_TEST
            "#{@qualified_column_name} BETWEEN #{values[0]} AND #{values[1]}"
          when IN_TEST
            "#{@qualified_column_name} IN (#{values.map { |v| v }.join(',')})"
          else
            range_or_standard_to_string(operator, values)
          end
        end
      end

      def self.from_definition(parameter_definition, op_val)
        op_val.data_type = parameter_definition.data_type if op_val.data_type == :string && parameter_definition.data_type != :string
        new(parameter_definition.column, op_val)
      end

      private

      def range_or_standard_to_string(operator, values)
        if @is_an_or_range
          '(' << values.map { |v| "#{@qualified_column_name} #{operator} #{v}" }.join(' OR ') << ')'
        else
          "#{@qualified_column_name} #{operator} #{values.first}"
        end
      end
    end
  end
end
