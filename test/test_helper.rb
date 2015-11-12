if ENV['WITH_COVER']
  require 'simplecov'
  SimpleCov.start
end
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'dataminer'

require 'minitest/autorun'
