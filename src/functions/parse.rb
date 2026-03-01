# frozen_string_literal: true

# Documentation for Cdd
module Cdd
  # Module for functions handling
  module Functions
    # Parser for functions
    class Parser
      # Parses functions from tokens and adds to ir
      # @param tokens [Array] tokens array
      # @param ir [Cdd::IR] Intermediate Representation
      def self.parse(tokens, ir)
        in_api_client = false
        current_http_method = nil
        current_http_path = nil
        
        tokens.each_with_index do |token, i|
          if token[1] == :on_kw && token[2] == "class"
            name_token = tokens[i+1..].find { |t| t[1] == :on_const }
            if name_token && name_token[2] == "ApiClient"
              in_api_client = true
            end
          elsif token[1] == :on_kw && token[2] == "end" && in_api_client
            # Simplified scoping
          elsif token[1] == :on_comment
            if token[2] =~ /#\s*@api_client\s+([A-Z]+)\s+(\S+)/
              current_http_method = $1.downcase
              current_http_path = $2
              path = $2
              ir.openapi_spec["paths"] ||= {}
              ir.openapi_spec["paths"][path] ||= {}
              ir.openapi_spec["paths"][path][current_http_method] ||= {
                "responses" => { "200" => { "description" => "OK" } }
              }
            end
          elsif token[1] == :on_kw && token[2] == "def" && in_api_client
            # find args
            j = i + 1
                        while j < tokens.size && tokens[j][1] != :on_nl && tokens[j][1] != :on_semicolon && !(tokens[j][1] == :on_kw && tokens[j][2] == 'end')
              if tokens[j][1] == :on_label
                arg_name = tokens[j][2].sub(':', '')
                if current_http_path && current_http_method && ir.openapi_spec.dig("paths", current_http_path, current_http_method)
                  op = ir.openapi_spec["paths"][current_http_path][current_http_method]
                  if arg_name == "body"
                    op["requestBody"] ||= { "content" => { "application/json" => {} } }
                  else
                    op["parameters"] ||= []
                    unless op["parameters"].any? { |p| p["name"] == arg_name }
                      in_path = current_http_path.include?("{#{arg_name}}") ? "path" : "query"
                      op["parameters"] << { "name" => arg_name, "in" => in_path }
                    end
                  end
                end
              end
              j += 1
            end
          end
        end
      end
    end
  end
end
