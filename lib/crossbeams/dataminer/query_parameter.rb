module Crossbeams
  module Dataminer

    class QueryParameter

      NULL_TEST    = /NULL/i
      NOT_TEST     = /NOT/i
      BETWEEN_TEST = /BETWEEN/i
      IN_TEST      = /IN/i

      def initialize(namespaced_name, op_val, options={})
        @qualified_column_name = namespaced_name#.is_a?(String) ? namespaced_name.split('.') : Array(namespaced_name)
        @op_val         = op_val
        @is_an_or_range = options[:is_an_or_range] || false
        @convert        = options[:convert] || :to_s
      end

      def to_string
        operator = @op_val.operator_for_sql
        values   = @op_val.values_for_sql

        if values.first =~ NULL_TEST
          if operator =~ NOT_TEST
            "#{@qualified_column_name} IS NOT NULL"
          else
            "#{@qualified_column_name} IS NULL"
          end
        elsif operator =~ BETWEEN_TEST
          "#{@qualified_column_name} BETWEEN #{values[0]} AND #{values[1]}"
        elsif operator =~ IN_TEST
          "#{@qualified_column_name} IN (#{values.map {|v| v}.join(',')})"
        elsif @is_an_or_range
          '(' << values.map {|v| "#{@qualified_column_name} #{operator} #{v}" }.join(' OR ') << ')'
        else
          "#{@qualified_column_name} #{operator} #{values.first}"
        end
      end

      def self.from_definition(parameter_definition, op_val)
        op_val.data_type = parameter_definition.data_type if op_val.data_type == :string && parameter_definition.data_type != :string
        self.new(parameter_definition.column, op_val)
      end

    end

  end
end
