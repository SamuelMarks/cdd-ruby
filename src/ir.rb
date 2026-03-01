# frozen_string_literal: true

# Documentation for Cdd
module Cdd
  # Intermediate Representation of a Codebase
  class IR
    attr_accessor :classes, :routes, :openapi_spec, :tests, :mocks

    # Documentation for initialize
    def initialize
      @classes = []
      @routes = []
      @openapi_spec = {
        "openapi" => "3.2.0",
        "info" => { "title" => "Generated API", "version" => "1.0.0" },
        "paths" => {},
        "components" => { "schemas" => {} }
      }
      @tests = []
      @mocks = []
    end

    # Documentation for to_h
    def to_h
      {
        "classes" => @classes,
        "routes" => @routes,
        "openapi" => @openapi_spec,
        "tests" => @tests,
        "mocks" => @mocks
      }
    end
  end
end
