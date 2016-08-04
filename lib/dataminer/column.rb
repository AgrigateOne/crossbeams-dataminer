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
    attr_accessor :name, :sequence_no, :caption, :namespaced_name, :data_type,
                  :width, :format, :hide, :groupable, :group_by_seq,
                  :group_sum, :group_avg, :group_min, :group_max

    def initialize(sequence_no, parse_path, options={})
      @name         = get_name(parse_path)
      @namespaced_name = get_namespaced_name(parse_path)
      @sequence_no  = sequence_no
      @parse_path   = parse_path
      @caption      = name.sub(/_id\z/, '').tr('_', ' ').sub(/\A\w/) { |match| match.upcase }
      @width        = options[:width]
      @data_type    = options[:data_type]    || :string
      @format       = options[:format]
      @hide         = options[:hide]         || false

      @groupable    = options[:groupable]    || false
      @group_by_seq = options[:group_by_seq]
      @group_sum    = options[:group_sum]    || false
      @group_avg    = options[:group_avg]    || false
      @group_min    = options[:group_min]    || false
      @group_max    = options[:group_max]    || false
    end

    def self.create_from_parse(seq, path)
      new(seq, path)
    end

    def to_hash
      hash = {}
      [:name, :sequence_no, :caption, :namespaced_name, :data_type, :width,
       :format, :hide, :groupable, :group_by_seq,
       :group_sum, :group_avg, :group_min, :group_max ].each {|a| hash[a] = self.send(a) }
      hash
    end

    def modify_from_hash(column)
      self.sequence_no     = column[:sequence_no]
      self.namespaced_name = column[:namespaced_name]
      self.data_type       = column[:data_type]
      self.caption         = column[:caption]
      self.width           = column[:width]
      self.format          = column[:format]
      self.hide            = column[:hide]
      self.groupable       = column[:groupable]
      self.group_by_seq    = column[:group_by_seq]
      self.group_sum       = column[:group_sum]
      self.group_avg       = column[:group_avg]
      self.group_min       = column[:group_min]
      self.group_max       = column[:group_max]
    end

    private

    # Column name - returns field name or its alias if provided.
    def get_name(restarget)
      if restarget['name']
        restarget['name']
      else
        if restarget['val'][PgQuery::FUNC_CALL]
          restarget['val'][PgQuery::FUNC_CALL]['funcname'].last[PgQuery::STRING]['str']
        else
          fld = restarget['val'][PgQuery::COLUMN_REF]['fields'].last
          field_parse(fld)
        end
      end
    end

    # Namespaced name as alias.fieldname. Does not return the aliased name.
    def get_namespaced_name(restarget)
      if restarget['val'][PgQuery::FUNC_CALL]
        restarget['val'][PgQuery::FUNC_CALL]['funcname'].join('.') #....... #FIXME....return function with arguments...?
      elsif restarget['val'][PgQuery::COLUMN_REF]
        restarget['val'][PgQuery::COLUMN_REF]['fields'].map {|f| field_parse(f) }.join('.')
      else
        nil # Probably a calculated field - can't be used as a query parameter
      end
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
