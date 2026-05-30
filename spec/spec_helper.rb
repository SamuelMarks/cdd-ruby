# frozen_string_literal: true

require 'simplecov'

require 'simplecov_json_formatter'
SimpleCov.formatter = SimpleCov::Formatter::JSONFormatter
SimpleCov.start do
  enable_coverage :branch
end
require 'minitest/autorun'
require_relative '../src/cdd'
