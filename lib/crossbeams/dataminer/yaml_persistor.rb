module Crossbeams
  module Dataminer
    # Read and write a hash representation of a report to/from file.
    class YamlPersistor
      # New
      # @param pathname [string] the path to which to save or from which to read a Hash.
      def initialize(pathname)
        raise ArgumentError, 'Pathname cannot be blank' if pathname.nil? || pathname.strip.empty?

        @pathname = pathname
      end

      # Write the hash representation to file as YAML.
      # @param hash [hash] the input hash.
      # @return [void]
      def save(hash)
        str = convert_sql_to_multiline_yaml(hash)
        File.open(@pathname, 'w') { |f| f << str }
      end

      # Load the contents of the YAML file and return a hash.
      # @return [hash] The file content converted to a Hash.
      def to_hash
        YAML.load(File.read(@pathname))
      end

      private

      # To make it easier to diff SQL changes over time,
      # use the literal style for storing SQL strings.
      #
      # Change the SQL stored in the YAML from:
      #   :sql: "SELECT * \r\nFROM table"
      #
      # to:
      #   :sql: |
      #     SELECT *
      #     FROM table
      def convert_sql_to_multiline_yaml(hash)
        sql = hash[:sql].strip
        nh = hash.dup
        nh[:sql] = 'XXSQLXX'
        str = nh.to_yaml
        ns = ":sql: |\n  #{sql.gsub(/(\r\n|\r|\n)/, "\n  ")}"
        str.sub(':sql: XXSQLXX', ns)
      end
    end
  end
end
