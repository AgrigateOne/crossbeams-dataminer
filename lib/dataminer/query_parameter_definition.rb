module Dataminer

  class QueryParameterDefinition
    attr_accessor :caption, :data_type, :control_type, :list_def, :ui_priority, :default_value

    def initialize(column, options={})
      @column        = column
      @caption       = @column
      @data_type     = options[:data_type]    || :string
      @control_type  = options[:control_type] || :text
      @list_def      = options[:list_def]
      @ordered_list  = @list_def && @list_def.is_a?(String) && @list_def =~ /order\s+by/i
      @ui_priority   = options[:ui_priority] || 1
      @default_value = options[:default_value]
    end

    # TODO: validate attributes...

    def list_is_ordered?
      @ordered_list
    end

    # array_val = parm.build_list {|sql| ActiveRecord::Base.connection.select_all(sql) }
    # ... or pass db connection?
    def build_list(&block)
      results = nil

      if @list_def.is_a? Array
        return @list_def.map {|a| a.is_a?(Hash) ? a.values : a }
      elsif @list_def.is_a? Hash
        return @list_def.map {|k,v| [k,v] }
      else
        results = yield @list_def # calling code must convert string to results. (AR query e.g.)
      end

      return [] if results.nil?

      if results.is_a? Array
        results.map {|a| a.is_a?(Hash) ? a.values : a }
      elsif results.is_a? Hash
        return results.map {|k,v| [k,v] }
      elsif results.respond_to?:split
        results.split(',')
      else
        Array(results)
      end
    end
  end

end
