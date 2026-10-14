# frozen_string_literal: true

require 'simplecov'

require 'simplecov_json_formatter'
SimpleCov.formatter = SimpleCov::Formatter::JSONFormatter
SimpleCov.start do
  command_name "Test#{Time.now.to_i}#{rand(1000)}"
  enable_coverage :branch
  minimum_coverage line: 100, branch: 100
end
require 'minitest/autorun'
require_relative '../src/cdd'
