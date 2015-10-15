require "dataminer/version"
require "dataminer/report"
require "dataminer/column"
require "dataminer/query_parameter"
require "dataminer/query_parameter_definition"
require "dataminer/operator_value"
require "dataminer/yaml_persistor"
require "pg_query"
require 'yaml'

module Dataminer

  class SyntaxError < StandardError; end

end
