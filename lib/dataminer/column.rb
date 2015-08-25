module Dataminer

  class Column
    attr_accessor :name, :sequence_no, :caption, :namespaced_name

    def initialize(sequence_no, parse_path, options={})
      @name         = get_name(parse_path)
      @namespaced_name = get_namespaced_name(parse_path)
      @sequence_no  = sequence_no
      @parse_path   = parse_path
      @caption      = name.sub(/_id\z/, '').tr('_', ' ').sub(/\A\w/) { |match| match.upcase }
      @width        = options[:width]
      @datatype     = options[:data_type]    || :string
      @format       = options[:format]
      @hide         = options[:hide]         || false

      @groupable    = options[:groupable]    || false
      @group_by_seq = options[:group_by_seq]
      @group_sum    = options[:group_sum]    || false
      @group_avg    = options[:group_min]    || false
      @group_min    = options[:group_max]    || false
    end

    def self.create_from_parse(seq, path)
      self.new(seq, path)
    end
    
    def ast_name
      if @parse_path['val']['FUNCCALL']
        @parse_path['val']['FUNCCALL']['funcname'].join('.') #.......
      else
        @parse_path['val']['COLUMNREF']['fields'].join('.')
      end
    end

    private

    # {"RESTARGET"=>{"name"=>nil, "indirection"=>nil, "val"=>{"COLUMNREF"=>{"fields"=>["b", "name"], "location"=>12}}, "location"=>12}}
    # {"RESTARGET"=>{"name"=>nil, "indirection"=>nil, "val"=>{"COLUMNREF"=>{"fields"=>["u", "id"], "location"=>7}}, "location"=>7}}
    # {"RESTARGET"=>{"name"=>nil, "indirection"=>nil, "val"=>{"COLUMNREF"=>{"fields"=>["id"], "location"=>7}}, "location"=>7}}
    # {"RESTARGET"=>{"name"=>nil, "indirection"=>nil, "val"=>{"COLUMNREF"=>{"fields"=>[{"A_STAR"=>{}}], "location"=>7}}, "location"=>7}}
    # {"RESTARGET"=>{"name"=>"testo", "indirection"=>nil, "val"=>{"FUNCCALL"=>{"funcname"=>["pg_catalog", "date_part"], "args"=>[{"A_CONST"=>{"val"=>"year", "location"=>15}}, {"COLUMNREF"=>{"fields"=>["created_at"], "location"=>27}}], "agg_order"=>nil, "agg_filter"=>nil, "agg_within_group"=>false, "agg_star"=>false, "agg_distinct"=>false, "func_variadic"=>false, "over"=>nil, "location"=>7}}, "location"=>7}}
    # {"RESTARGET"=>{"name"=>nil, "indirection"=>nil, "val"=>{"FUNCCALL"=>{"funcname"=>["pg_catalog", "date_part"], "args"=>[{"A_CONST"=>{"val"=>"year", "location"=>15}}, {"COLUMNREF"=>{"fields"=>["created_at"], "location"=>27}}], "agg_order"=>nil, "agg_filter"=>nil, "agg_within_group"=>false, "agg_star"=>false, "agg_distinct"=>false, "func_variadic"=>false, "over"=>nil, "location"=>7}}, "location"=>7}}
    def get_name(restarget)
      if restarget['name']
        restarget['name']
      else
        if restarget['val']['FUNCCALL']
          restarget['val']['FUNCCALL']['funcname'].last
        else
          fld = restarget['val']['COLUMNREF']['fields'].last
          if fld.is_a? String
            fld
          else
            fld.keys[0]
          end
        end
      end
    end

    def get_namespaced_name(restarget)
      if restarget['val']['FUNCCALL']
        restarget['val']['FUNCCALL']['funcname'].join('.') #.......
      else
        restarget['val']['COLUMNREF']['fields'].join('.')
      end
    end

  end

end
