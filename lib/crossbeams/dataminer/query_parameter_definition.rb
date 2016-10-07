module Crossbeams
  module Dataminer

    class QueryParameterDefinition
      attr_accessor :column, :caption, :data_type, :control_type, :list_def, :ui_priority, :default_value, :list_values

      def initialize(column, options={})
        @column        = column # THIS IS NAMESPACED....
        @caption       = options[:caption]      || @column
        @data_type     = options[:data_type]    || :string
        @control_type  = options[:control_type] || :text
        @list_def      = options[:list_def]
        @ordered_list  = @list_def && @list_def.is_a?(String) && @list_def =~ /order\s+by/i
        @ui_priority   = options[:ui_priority] || 1
        @default_value = options[:default_value]
        @list_values   = []
      end

      # TODO: validate attributes...

      def ==(other)
        other.column == self.column
      end

      def list_is_ordered?
        @ordered_list
      end

      def to_s
        "PARAM COL: #{@column}: CAPTION: #{@caption} TYPE: #{@data_type} UI: #{@control_type} DEFAULT: #{@default_value}"
      end

      def to_hash(with_list_values=false)
        xtra = with_list_values ? {list_values: alter_it(@list_values)} : {}

        {column: @column, caption: @caption, data_type: @data_type, control_type: @control_type,
         default_value: @default_value, ordered_list: @ordered_list,
         ui_priority: @ui_priority, list_def: @list_def}.merge(xtra)
      end

      def self.create_from_hash(hash)
        new = self.new(hash[:column], hash)
        new
      end

      # array_val = parm.build_list {|sql| ActiveRecord::Base.connection.select_all(sql) }
      # ... or pass db connection?
      def build_list(&block)
        results = nil

        if @list_def.is_a? Array
          @list_values = @list_def.map {|a| a.is_a?(Hash) ? a.values : a }
          return self
        elsif @list_def.is_a? Hash
          @list_values = @list_def.map {|k,v| [k,v] }
          return self
        else
          results = yield @list_def # calling code must convert string to results. (AR query e.g.)
        end

        results ||= []

        if results.is_a? Array
          @list_values = results.map {|a| a.is_a?(Hash) ? a.values : a }
        elsif results.is_a? Hash
          @list_values = results.map {|k,v| [k,v] }
        elsif results.respond_to?:split
          @list_values = results.split(',')
        else
          @list_values = Array(results)
        end
        #@list_values
        self
      end

      private

      def alter_it(ar)
        if ar.first.is_a?(Array)
          ar.map {|a| {:label => a.first, :val => a.last} }
        else
          ar.map {|a| {:label => a, :val => a} }
        end
      end

    end

  end
end
