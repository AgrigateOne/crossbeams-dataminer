module Dataminer

  class YamlPersistor

    def initialize(pathname)
      raise ArgumentError, 'Pathname cannot be blank' if pathname.nil? || pathname.strip.empty?
      @pathname = pathname
    end

    def save(hash)
      File.open(@pathname, 'w') {|f| f << hash.to_yaml }
    end

    def to_hash
      YAML.load(File.read(@pathname))
    end
  end
end
