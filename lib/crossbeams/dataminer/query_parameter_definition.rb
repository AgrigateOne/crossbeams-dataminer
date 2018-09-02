module Crossbeams
  module Dataminer
    class QueryParameterDefinition
      attr_accessor :column, :caption, :data_type, :control_type, :ui_priority, :default_value, :list_values
      attr_reader :list_def

      def initialize(column, options = {})
        @column        = column # THIS IS NAMESPACED....
        @caption       = options.fetch(:caption, @column)
        @data_type     = options.fetch(:data_type, :string)
        @control_type  = options.fetch(:control_type, :text)
        self.list_def  = options[:list_def]
        @ui_priority   = options.fetch(:ui_priority, 1)
        @default_value = options[:default_value]
        @list_values   = []
      end

      # TODO: validate attributes...

      def list_def=(value)
        @ordered_list = false
        if value&.is_a?(String)
          raise ArgumentError, 'List definition SQL MUST be a SELECT' if value.match?(/insert |update |delete /i)
          @ordered_list = value.match?(/order\s+by/i)
        end
        @list_def = value
      end

      def ==(other)
        other.column == column
      end

      def list_is_ordered?
        @ordered_list
      end

      def includes_list_options?
        @list_def.is_a?(Array) || @list_def.is_a?(Hash)
      end

      def to_s
        "PARAM COL: #{@column}: CAPTION: #{@caption} TYPE: #{@data_type} UI: #{@control_type} DEFAULT: #{@default_value}"
      end

      def to_hash(with_list_values = false)
        xtra = with_list_values ? { list_values: alter_it(@list_values) } : {}

        { column: @column,             caption: @caption,             data_type: @data_type,
          control_type: @control_type, default_value: @default_value, ordered_list: @ordered_list,
          ui_priority: @ui_priority,   list_def: @list_def }.merge(xtra)
      end

      def self.create_from_hash(hash)
        new = self.new(hash[:column], hash)
        new
      end

      def build_list
        if block_given?
          results = yield(@list_def) || [] # calling code must convert string to results. (AR query e.g.)
          build_values_from_block_results(results)
        else
          calculate_values_from_definition
        end
        self
      end

      private

      def build_values_from_block_results(results)
        @list_values = case results
                       when Array
                         results.map { |a| a.is_a?(Hash) ? a.values : a }
                       when Hash
                         results.map { |k, v| [k, v] }
                       when respond_to?(:split)
                         results.split(',')
                       else
                         Array(results)
                       end
      end

      def calculate_values_from_definition
        if @list_def.is_a? Array
          @list_values = @list_def.map { |a| a.is_a?(Hash) ? a.values : a }
        elsif @list_def.is_a? Hash
          @list_values = @list_def.map { |k, v| [k, v] }
        end
      end

      def alter_it(ar)
        if ar.first.is_a?(Array)
          ar.map { |a| { label: a.first, val: a.last } }
        else
          ar.map { |a| { label: a, val: a } }
        end
      end
    end
  end
end
