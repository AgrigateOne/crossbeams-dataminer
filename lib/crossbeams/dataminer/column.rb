module Crossbeams
  module Dataminer
    # {"ResTarget"=>{"val"=>{"ColumnRef"=>{"fields"=>[{"String"=>{"str"=>"id"}}], "location"=>7}}, "location"=>7}}
    # {"ResTarget"=>{"val"=>{"ColumnRef"=>{"fields"=>[{"String"=>{"str"=>"u"}}, {"String"=>{"str"=>"id"}}], "location"=>7}}, "location"=>7}}
    # {"ResTarget"=>{"name"=>"nine", "val"=>{"A_Const"=>{"val"=>{"Integer"=>{"ival"=>9}}, "location"=>21}}, "location"=>21}}
    # {"ResTarget"=>{"val"=>{"ColumnRef"=>{"fields"=>[{"A_Star"=>{}}], "location"=>7}}, "location"=>7}}
    # {"ResTarget"=>
    #     {"val"=>
    #       {"FuncCall"=>
    #         {"funcname"=>[{"String"=>{"str"=>"date"}}],
    #          "args"=>[{"ColumnRef"=>{"fields"=>[{"String"=>{"str"=>"u"}}, {"String"=>{"str"=>"created_at"}}], "location"=>37}}],
    #          "location"=>32}},
    #      "location"=>32}}

    class Column
      attr_accessor :name,      :sequence_no, :caption,   :namespaced_name, :data_type,
                    :width,     :format,      :hide,      :groupable,       :group_by_seq,
                    :group_sum, :group_avg,   :group_min, :group_max,       :parse_path

      def initialize(sequence_no, parse_path, options = {})
        @name            = get_name(parse_path)
        @namespaced_name = get_namespaced_name(parse_path)
        @sequence_no     = sequence_no
        @parse_path      = parse_path
        @caption         = name.sub(/_id\z/, '').tr('_', ' ').sub(/\A\w/, &:upcase)
        @data_type       = options.fetch(:data_type, :string)

        %i[width format group_by_seq].each do |att|
          instance_variable_set("@#{att}", options[att])
        end

        %i[hide groupable group_sum group_avg group_min group_max].each do |att|
          instance_variable_set("@#{att}", options.fetch(att, false))
        end
      end

      # Create a Column from a PGQuery column definition.
      #
      # @param seq [Integer] The sequence
      # @param path [String] The path
      # @return Column.
      def self.create_from_parse(seq, path)
        new(seq, path)
      end

      # Column as a Hash.
      #
      # @return Hash.
      def to_hash
        hash = {}
        %i[name sequence_no caption namespaced_name data_type width
           format hide groupable group_by_seq
           group_sum group_avg group_min group_max].each { |a| hash[a] = send(a) }
        hash
      end

      # Update selected attributes from a Hash.
      #
      # @param column [Hash] the key/value hash using symbol keys.
      # @return void.
      def modify_from_hash(column)
        %i[sequence_no namespaced_name data_type caption width format hide
           groupable group_by_seq group_sum group_avg group_min group_max].each do |att|
          send("#{att}=", column[att])
        end
      end

      # Update selected attributes from another column.
      #
      # @param previous_column [Column] the Column with the desired attributes.
      # @return self.
      def update_from(previous_column)
        return self if previous_column.nil?
        %i[data_type caption width format hide
           groupable group_by_seq group_sum group_avg group_min group_max].each do |att|
          send("#{att}=", previous_column.send(att))
        end
        self
      end

      private

      # Column name - returns field name or its alias if provided.
      def get_name(restarget)
        if restarget['name']
          restarget['name']
        else
          get_name_from_val(restarget['val'])
        end
      end

      def get_name_from_val(val)
        if val[PgQuery::FUNC_CALL]
          val[PgQuery::FUNC_CALL]['funcname'].last[PgQuery::STRING]['str']
        else
          fld = val[PgQuery::COLUMN_REF]['fields'].last
          field_parse(fld)
        end
      end

      # Namespaced name as alias.fieldname. Does not return the aliased name.
      def get_namespaced_name(restarget)
        # Calculated fields or PgQuery::FUNC_CALL can't be used as a query parameter
        restarget['val'][PgQuery::COLUMN_REF]['fields'].map { |f| field_parse(f) }.join('.') if restarget['val'][PgQuery::COLUMN_REF]
      end

      # Return field node.
      def field_parse(field)
        if field[PgQuery::STRING]
          field[PgQuery::STRING]['str']
        elsif field[PgQuery::INTEGER]
          field[PgQuery::INTEGER]['ivar']
        elsif field[PgQuery::A_STAR]
          PgQuery::A_STAR
        else
          raise ArgumentError, "DataMiner: unknown key for Dataminer::Column - #{field.keys.join(', ')}"
        end
      end
    end
  end
end
