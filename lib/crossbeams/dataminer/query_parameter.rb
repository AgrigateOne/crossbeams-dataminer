module Crossbeams
  module Dataminer
    class QueryParameter
      NULL_TEST       = /NULL/i.freeze
      NOT_TEST        = /NOT/i.freeze
      BETWEEN_TEST    = /BETWEEN/i.freeze
      IN_TEST         = /IN/i.freeze
      MATCH_NULL_TEST = /MATCH_OR_NULL/i.freeze

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

        if operator.match(MATCH_NULL_TEST)
          "(#{@qualified_column_name} = #{values.first} OR #{@qualified_column_name} IS NULL)"
        elsif values.first.to_s.match?(NULL_TEST)
          op_type = operator.match?(NOT_TEST) ? true : false
          "#{@qualified_column_name} #{NOT_NULL_TEST[op_type]}"
        else
          case operator
          when BETWEEN_TEST
            "#{@qualified_column_name} BETWEEN #{values[0]} AND #{values[1]}"
          when IN_TEST
            if values.empty?
              '(1 = 2)'
            else
              "#{@qualified_column_name} IN (#{values.map { |v| v }.join(',')})"
            end
          when MATCH_NULL_TEST
            match_null(operator, values)
          else
            range_or_standard_to_string(operator, values)
          end
        end
      end

      def to_text # rubocop:disable Metrics/AbcSize
        operator = @op_val.operator_for_text
        values   = @op_val.values_for_sql

        if operator == 'is equal to or blank'
          "#{unqualified_column_name} is #{values.first} or blank"
        elsif values.first.to_s.match?(NULL_TEST)
          "#{unqualified_column_name} #{operator}"
        elsif @op_val.data_type == :boolean
          if @op_val.values.first
            "is #{unqualified_column_name}"
          else
            "is not #{unqualified_column_name}"
          end
        else
          case operator
          when BETWEEN_TEST
            "#{unqualified_column_name} is #{operator} #{values[0]} and #{values[1]}"
          when /any of/i
            if values.empty?
              "#{unqualified_column_name} check is ignored"
            else
              "#{unqualified_column_name} #{operator} #{values.map { |v| v }.join(', ').sub(", #{values.last}", " or #{values.last}")}"
            end
          else
            range_or_standard_to_text(operator, values) # .map { |v| v.to_s.tr('%', '') })
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

      def range_or_standard_to_text(operator, values)
        if @is_an_or_range
          '(' << values.map { |v| "#{unqualified_column_name} #{operator} #{v.to_s.tr('%', '')}" }.join(' OR ') << ')'
        else
          "#{unqualified_column_name} #{operator} #{values.first.to_s.tr('%', '')}"
        end
      end

      def unqualified_column_name
        @qualified_column_name.split('.').last
      end
    end
  end
end
