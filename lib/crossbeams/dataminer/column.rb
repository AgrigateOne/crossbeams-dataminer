module Crossbeams
  module Dataminer
    class Column
      attr_accessor :name,      :sequence_no, :caption,   :namespaced_name, :data_type,
                    :width,     :format,      :hide,      :groupable,       :group_by_seq,
                    :group_sum, :group_avg,   :group_min, :group_max,       :parse_path,
                    :pinned,    :funcname,    :col_fingerprint

      def initialize(sequence_no, parse_path, options = {}) # rubocop:disable Metrics/AbcSize
        @name            = get_name(parse_path)
        @namespaced_name = get_namespaced_name(parse_path)
        @sequence_no     = sequence_no
        @parse_path      = parse_path
        @caption         = name.sub(/_id\z/, '').tr('_', ' ').sub(/\A\w/, &:upcase)
        @data_type       = options.fetch(:data_type, :string)
        @funcname        = get_funcname(parse_path)
        build_fingerprint
        # puts "#{name} - FP: #{col_fingerprint}"
        if col_fingerprint.empty?
          puts "Crossbeams::Datminer::Column - unable to build a fingerprint for: #{name}..."
          p col_node
        end

        %i[width format group_by_seq pinned].each do |att|
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
           format hide pinned groupable group_by_seq
           group_sum group_avg group_min group_max].each { |a| hash[a] = send(a) }
        hash
      end

      # Update selected attributes from a Hash.
      #
      # @param column [Hash] the key/value hash using symbol keys.
      # @return void.
      def modify_from_hash(column)
        %i[sequence_no namespaced_name data_type caption width format hide pinned
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

        %i[data_type caption width format hide pinned
           groupable group_by_seq group_sum group_avg group_min group_max].each do |att|
          send("#{att}=", previous_column.send(att))
        end
        self
      end

      # Return an array of unique string values from a CASE statement column.
      #
      # @return Array
      def case_string_values
        @res = Set.new
        get_col_results(@parse_path.val.case_expr) if @parse_path.val.case_expr
        @res.to_a
      end

      # Is this column an aggregate function? (sum, min, max, count, avg)
      #
      # @return Boolean
      def aggregate_function?
        %w[sum avg min max count].include?(funcname)
      end

      def match_node?(node)
        @fingerprint = []
        calc_fingerprint(node)
        group_fingerprint = @fingerprint.join('.')
        group_fingerprint == col_fingerprint
      end

      def col_node
        parse_path.val
      end

      private

      def get_col_results(case_expr) # rubocop:disable Metrics/AbcSize
        case_expr.args.each do |node|
          if node.case_when.result.case_expr
            get_col_results(node.case_when.result.case_expr)
          else
            apply_case_value(node.case_when.result)
          end
        end

        return unless case_expr.defresult

        if case_expr.defresult.case_expr
          get_col_results(case_expr.defresult.case_expr)
        else
          apply_case_value(case_expr.defresult)
        end
      end

      def apply_case_value(node) # rubocop:disable Metrics/AbcSize
        return if node.a_const.val.null

        val = if node.a_const.val.integer
                node.a_const.val.integer.ival
              elsif node.a_const.val.string
                node.a_const.val.string.str
              else
                "NOTKNOWN: #{node.a_const}"
              end

        @res << val
      end

      # Column name - returns field name or its alias if provided.
      def get_name(restarget) # rubocop:disable Metrics/AbcSize
        return restarget.name unless restarget.name.nil? || restarget.name.empty?

        if restarget.val.column_ref
          field_parse(restarget.val.column_ref.fields.last)
        else
          restarget.val.func_call.funcname.last.string.str
        end
      end

      # Namespaced name as alias.fieldname. Does not return the aliased name.
      def get_namespaced_name(restarget)
        # Calculated fields or PgQuery::FUNC_CALL can't be used as a query parameter
        restarget.val.column_ref.fields.map { |f| field_parse(f) }.join('.') if restarget.val.column_ref
      end

      def get_funcname(restarget)
        return nil unless restarget.val.func_call

        restarget.val.func_call.funcname.last.string.str
      end

      def build_fingerprint
        @fingerprint = []
        calc_fingerprint(col_node)
        @col_fingerprint = @fingerprint.join('.')
      end

      # Take a node and combine string and int parts of its tree to generate a "fingerprint".
      def calc_fingerprint(node) # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
        @fingerprint << node.string.str if node.respond_to?(:string) && node.string
        @fingerprint << node.integer.ival if node.respond_to?(:integer) && node.integer
        @fingerprint << '*' if node.respond_to?(:a_star) && node.a_star
        @fingerprint << node.nulltesttype if node.respond_to?(:nulltesttype) && node.nulltesttype
        @fingerprint << node.boolop if node.respond_to?(:boolop) && node.boolop
        @fingerprint << node.sub_link_type if node.respond_to?(:sub_link_type) && node.sub_link_type
        @fingerprint << node.relname if node.respond_to?(:relname) && node.relname
        @fingerprint << node.limit_option if node.respond_to?(:limit_option) && node.limit_option

        %i[type_cast case_expr case_when rexpr kind lexpr a_expr
           a_const val arg expr func_call result column_ref
           coalesce_expr null_test type_name bool_expr sub_link
           subselect select_stmt res_target range_var where_clause].each do |meth|
          calc_fingerprint(node.send(meth)) if node.respond_to?(meth) && !node.send(meth).nil?
        end

        if node.respond_to?(:list) && node.list
          if node.list.respond_to?(:each)
            node.list.each { |f| calc_fingerprint(f) }
          else
            calc_fingerprint(node.list)
          end
        end
        node.items.each { |f| calc_fingerprint(f) } if node.respond_to?(:items) && node.items
        node.funcname.each { |f| calc_fingerprint(f) } if node.respond_to?(:funcname) && node.funcname
        node.names.each { |n| calc_fingerprint(n) } if node.respond_to?(:names) && node.names
        node.args.each { |n| calc_fingerprint(n) } if node.respond_to?(:args) && node.args
        node.fields.each { |n| calc_fingerprint(n) } if node.respond_to?(:fields) && node.fields
        node.target_list.each { |n| calc_fingerprint(n) } if node.respond_to?(:target_list) && node.target_list
        node.from_clause.each { |n| calc_fingerprint(n) } if node.respond_to?(:from_clause) && node.from_clause
        node.distinct_clause.each { |n| calc_fingerprint(n) } if node.respond_to?(:distinct_clause) && node.distinct_clause
        node.group_clause.each { |n| calc_fingerprint(n) } if node.respond_to?(:group_clause) && node.group_clause
        node.window_clause.each { |n| calc_fingerprint(n) } if node.respond_to?(:window_clause) && node.window_clause
        node.sort_clause.each { |n| calc_fingerprint(n) } if node.respond_to?(:sort_clause) && node.sort_clause

        return unless node.respond_to?(:name) && node.name

        if node.name.is_a?(Google::Protobuf::RepeatedField)
          node.name.each { |f| calc_fingerprint(f) }
        else
          calc_fingerprint(node.name)
        end
      rescue StandardError => e
        puts "Crossbeams::Dataminer::Column - fingerprinting failed: #{e.message}"
        puts "COL: #{name}"
        p node
      end

      # Return field node.
      def field_parse(field)
        node_type = field.node
        case node_type
        when :string
          field.string.str
        when :integer
          field.integer.ivar
        when :a_star
          'pgq_a_star'
        else
          raise ArgumentError, "DataMiner: unknown key for Dataminer::Column - #{node_type - field.to_s}"
        end
      end
    end
  end
end
