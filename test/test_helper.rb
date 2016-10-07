if ENV['WITH_COVER']
  require 'simplecov'
  SimpleCov.start
end
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'crossbeams/dataminer'

require 'minitest/autorun'
