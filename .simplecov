require 'simplecov'
require 'simplecov-json'
SimpleCov.start 'rails' do
  # any custom configs like groups and filters can be here at a central place
  enable_coverage :branch
  formatter SimpleCov::Formatter::MultiFormatter[
    SimpleCov::Formatter::JSONFormatter,
    SimpleCov::Formatter::HTMLFormatter
  ]
  add_filter 'phoenix-tests'
end
