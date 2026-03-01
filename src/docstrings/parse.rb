# frozen_string_literal: true

# Documentation for Cdd
module Cdd
  # Module for docstrings handling
  module Docstrings
    # Parser for docstrings
    class Parser
      # Parses docstrings from tokens and adds to ir
      # @param tokens [Array] tokens array
      # @param ir [Cdd::IR] Intermediate Representation
      def self.parse(tokens, ir)
        current_tags = []
        tokens.each do |token|
          if token[1] == :on_comment
            comment = token[2]
            if comment =~ /#\s*@server\s+(\S+)\s*(.*)/
              ir.openapi_spec["servers"] ||= []
              ir.openapi_spec["servers"] << { "url" => $1, "description" => $2.strip }
            elsif comment =~ /#\s*@server_var\s+(\S+)\s+(\w+)\s+(\S+)(?:\s+(.*))?/
  url, var_name, default_val, rest = $1, $2, $3, ($4 || "")
  pairs = {}
  parts = rest.split(' ')
  new_rest = []
  parts.each do |part|
    if part.start_with?('description:')
      new_rest << part.sub(/^description:/, '')
    elsif part.include?(':')
      k, v = part.split(':', 2)
      pairs[k] = v
    else
      new_rest << part
    end
  end
  server = (ir.openapi_spec["servers"] ||= []).find { |s| s["url"] == url }
  if server
    server["variables"] ||= {}
    var_obj = { "default" => default_val }
    var_obj["enum"] = pairs["enum"].split(',') if pairs["enum"]
    var_obj["description"] = new_rest.join(' ').strip unless new_rest.empty?
    server["variables"][var_name] = var_obj
  end
elsif comment =~ /#\s*@op_server_var\s+(\S+)\s+(\w+)\s+(\S+)(?:\s+(.*))?/
  url, var_name, default_val, rest = $1, $2, $3, ($4 || "")
  current_tags << { type: :op_server_var, url: url, var_name: var_name, default_val: default_val, rest: rest }
elsif comment =~ /#\s*@route_ref\s+(\S+)\s+(\w+)/
  ir.openapi_spec["paths"] ||= {}
  ir.openapi_spec["paths"][$1] = { "$ref" => "#/components/pathItems/#{$2}" }
elsif comment =~ /#\s*@param_example_ref\s+(\w+)\s+(\w+)\s+(\w+)/
  current_tags << { type: :param_example_ref, param_name: $1, example_name: $2, ref_name: $3 }
elsif comment =~ /#\s*@request_body_example_ref\s+(\S+)\s+(\w+)\s+(\w+)/
  current_tags << { type: :request_body_example_ref, media_type: $1, example_name: $2, ref_name: $3 }
elsif comment =~ /#\s*@response_example_ref\s+(\d+|default)\s+(\S+)\s+(\w+)\s+(\w+)/
  current_tags << { type: :response_example_ref, status: $1, media_type: $2, example_name: $3, ref_name: $4 }
            elsif comment =~ /#\s*@security_scheme\s+(\w+)\s+(\w+)(?:\s+(.*))?/
              scheme_name = $1
              type = $2
              rest = $3 || ""
              pairs = {}
parts = rest.split(' ')
new_rest = []
parts.each do |part|
  if part.start_with?('description:')
    new_rest << part.sub(/^description:/, '')
  elsif part.include?(':')
    k, v = part.split(':', 2)
    pairs[k] = v
  else
    new_rest << part
  end
end
rest = new_rest.join(' ')
              ir.openapi_spec["components"] ||= {}
              ir.openapi_spec["components"]["securitySchemes"] ||= {}
              scheme = { "type" => type }
              pairs.each { |k, v| scheme[k] = v }
              scheme["description"] = rest.strip unless rest.strip.empty?
              ir.openapi_spec["components"]["securitySchemes"][scheme_name] = scheme
            elsif comment =~ /#\s*@security\b(?:\s+(\w+))?(?:\s+(.*))?/
              scheme = $1
              scopes = $2 ? $2.split(/\s*,\s*/) : []
              if scheme
                current_tags << { type: :security, scheme: scheme, scopes: scopes }
              else
                current_tags << { type: :security, scheme: nil, scopes: [] }
              end
            elsif comment =~ /#\s*@schema_xml\s+(\w+)(?:\s+(.*))?/
  schema_name = $1
  rest = $2 || ""
  pairs = {}
  while rest =~ /^([a-zA-Z]+):(\S+)\s+(.*)$/
    pairs[$1] = $2
    rest = $3
  end
  if rest =~ /^([a-zA-Z]+):(\S+)$/
    pairs[$1] = $2
    rest = ""
  end
  ir.openapi_spec["components"] ||= {}
  ir.openapi_spec["components"]["schemas"] ||= {}
  ir.openapi_spec["components"]["schemas"][schema_name] ||= { "type" => "object" }
  ir.openapi_spec["components"]["schemas"][schema_name]["xml"] ||= {}
  pairs.each do |k, v|
    val = (v == 'true' ? true : (v == 'false' ? false : v))
    ir.openapi_spec["components"]["schemas"][schema_name]["xml"][k] = val
  end
                        elsif comment =~ /#\s*@schema_one_of\s+(\w+)\s+(.*)/


              schema_name = $1
              rest = $2
              # Check for discriminator mapping format: Base Type1:Dog,Type2:Cat
                                                        if rest =~ /^([a-zA-Z0-9_,\s]+)\s+discriminator:(\w+)(?:\s+mapping:([^\s]+))?(?:\s+defaultMapping:(\w+))?$/
                match_data = Regexp.last_match.dup

                                refs_str = match_data[1]
                prop = match_data[2]
                mapping_str = match_data[3]
                dm_str = match_data[4]

                refs = refs_str.split(/\s*,\s*/).map { |r| { "$ref" => "#/components/schemas/#{r}" } }
                schema = { "oneOf" => refs, "discriminator" => { "propertyName" => prop } }
                if mapping_str
                  mapping = {}
                  mapping_str.split(/\s*,\s*/).each do |pair|
                                        k, v = pair.split(":")
                    mapping[k] = "#/components/schemas/#{v}"
                  end
                  schema["discriminator"]["mapping"] = mapping
                end
                                                schema["discriminator"]["defaultMapping"] = "#/components/schemas/#{dm_str}" if dm_str

                
                
                ir.openapi_spec["components"] ||= {}
                ir.openapi_spec["components"]["schemas"] ||= {}
                ir.openapi_spec["components"]["schemas"][schema_name] = schema
              else
                refs = (rest || "").to_s.split(/\s*,\s*/).map { |r| { "$ref" => "#/components/schemas/#{r}" } }
                ir.openapi_spec["components"] ||= {}
                ir.openapi_spec["components"]["schemas"] ||= {}
                ir.openapi_spec["components"]["schemas"][schema_name] ||= { "oneOf" => refs }
              end
                        elsif comment =~ /#\s*@schema_any_of\s+(\w+)\s+(.*)/
              schema_name = $1
              rest = $2
              if rest =~ /^([a-zA-Z0-9_,\s]+)\s+discriminator:(\w+)(?:\s+mapping:([^\s]+))?(?:\s+defaultMapping:(\w+))?$/
                match_data = Regexp.last_match.dup
                refs_str = match_data[1]
                prop = match_data[2]
                mapping_str = match_data[3]
                dm_str = match_data[4]
                refs = refs_str.split(/\s*,\s*/).map { |r| { "$ref" => "#/components/schemas/#{r}" } }
                schema = { "anyOf" => refs, "discriminator" => { "propertyName" => prop } }
                if mapping_str
                  mapping = {}
                  mapping_str.split(/\s*,\s*/).each do |pair|
                    k, v = pair.split(":")
                    mapping[k] = "#/components/schemas/#{v}"
                  end
                  schema["discriminator"]["mapping"] = mapping
                end
                schema["discriminator"]["defaultMapping"] = "#/components/schemas/#{dm_str}" if dm_str
                ir.openapi_spec["components"] ||= {}
                ir.openapi_spec["components"]["schemas"] ||= {}
                ir.openapi_spec["components"]["schemas"][schema_name] = schema
              else
                refs = rest.split(/\s*,\s*/).map { |r| { "$ref" => "#/components/schemas/#{r}" } }
                ir.openapi_spec["components"] ||= {}
                ir.openapi_spec["components"]["schemas"] ||= {}
                ir.openapi_spec["components"]["schemas"][schema_name] ||= { "anyOf" => refs }
              end

            elsif comment =~ /#\s*@schema\s+(\w+)(?:\s+(.*))?/
              schema_name = $1
              rest = $2 || ""
              pairs = {}
parts = rest.split(' ')
new_rest = []
parts.each do |part|
  if part.start_with?('description:')
    new_rest << part.sub(/^description:/, '')
  elsif part.include?(':')
    k, v = part.split(':', 2)
    pairs[k] = v
  else
    new_rest << part
  end
end
rest = new_rest.join(' ')
              ir.openapi_spec["components"] ||= {}
              ir.openapi_spec["components"]["schemas"] ||= {}
              ir.openapi_spec["components"]["schemas"][schema_name] ||= { "type" => "object", "properties" => {} }
              pairs.each { |k, v| ir.openapi_spec["components"]["schemas"][schema_name][k] = v }
              ir.openapi_spec["components"]["schemas"][schema_name]["description"] = rest.strip unless rest.strip.empty?
            elsif comment =~ /#\s*@param\s+(\w+)\s+\[(\w+)\]\s+in:(\w+)(?:\s+(.*))?/
              name = $1
              schema_type = $2
              loc = $3
              rest = $4 || ""
              pairs = {}
parts = rest.split(' ')
new_rest = []
parts.each do |part|
  if part.start_with?('description:')
    new_rest << part.sub(/^description:/, '')
  elsif part.include?(':')
    k, v = part.split(':', 2)
    pairs[k] = v
  else
    new_rest << part
  end
end
rest = new_rest.join(' ')
              current_tags << { type: :param, name: name, schema_type: schema_type, in: loc, options: pairs, description: rest.strip }
            elsif comment =~ /#\s*@request_body_encoding\s+(\S+)\s+(\S+)(?:\s+(.*))?/
  media_type = $1
  property = $2
  rest = $3 || ""
  pairs = {}
  parts = rest.split(' ')
  new_rest = []
  parts.each do |part|
    if part.start_with?('description:')
      new_rest << part.sub(/^description:/, '')
    elsif part.include?(':')
      k, v = part.split(':', 2)
      pairs[k] = v
    else
      new_rest << part
    end
  end
  current_tags << { type: :request_body_encoding, media_type: media_type, property: property, options: pairs, description: new_rest.join(' ').strip }
            elsif comment =~ /#\s*@request_body\s+\[(\w+)\]\s+(\S+)(?:\s+(.*))?/
              schema_name = $1
              media_type = $2
              rest = $3 || ""
              pairs = {}
parts = rest.split(' ')
new_rest = []
parts.each do |part|
  if part.start_with?('description:')
    new_rest << part.sub(/^description:/, '')
  elsif part.include?(':')
    k, v = part.split(':', 2)
    pairs[k] = v
  else
    new_rest << part
  end
end
rest = new_rest.join(' ')
              current_tags << { type: :request_body, schema_name: schema_name, media_type: media_type, options: pairs, description: rest.strip }
            elsif comment =~ /#\s*@response\s+(\d+|default)(?:\s+\[(\w+)\]\s+(\S+))?(?:\s+(.*))?/
              status = $1
              schema_name = $2
              media_type = $3
              rest = $4 || ""
              pairs = {}
              parts = rest.split(' ')
              new_rest = []
              parts.each do |part|
                if part.start_with?('description:')
                  new_rest << part.sub(/^description:/, '')
                elsif part.include?(':')
                  k, v = part.split(':', 2)
                  pairs[k] = v
                else
                  new_rest << part
                end
              end
              current_tags << { type: :response, status: status, schema_name: schema_name, media_type: media_type, options: pairs, description: new_rest.join(' ').strip }
            elsif comment =~ /#\s*@operationId\s+(.*)/
              current_tags << { type: :operationId, value: $1.strip }
            elsif comment =~ /#\s*@tag\s+(.*)/
              current_tags << { type: :tag, value: $1.strip }
            elsif comment =~ /#\s*@callback\s+(\w+)\s+(\S+)\s+(get|put|post|delete|options|head|patch|trace|query)/i
              current_tags << { type: :callback, name: $1, url: $2, method: $3.downcase }
            elsif comment =~ /#\s*@callback_request_body\s+\[(\w+)\]\s+(\S+)(?:\s+(.*))?/
              current_tags << { type: :callback_request_body, schema_name: $1, media_type: $2, description: $3 ? $3.strip : nil }
            elsif comment =~ /#\s*@callback_response\s+(\d+|default)(?:\s+\[(\w+)\]\s+(\S+))?(?:\s+(.*))?/
              status = $1
              schema_name = $2
              media_type = $3
              rest = $4 || ""
              pairs = {}
              parts = rest.split(' ')
              new_rest = []
              parts.each do |part|
                if part.start_with?('description:')
                  new_rest << part.sub(/^description:/, '')
                elsif part.include?(':')
                  k, v = part.split(':', 2)
                  pairs[k] = v
                else
                  new_rest << part
                end
              end
              current_tags << { type: :callback_response, status: status, schema_name: schema_name, media_type: media_type, options: pairs, description: new_rest.join(' ').strip }
            elsif comment =~ /#\s*@response_header\s+(\d+|default)\s+([A-Za-z0-9_-]+)\s+\[(\w+)\](?:\s+(.*))?/
  status = $1
  name = $2
  schema_type = $3
  rest = $4 || ""
  pairs = {}
parts = rest.split(' ')
new_rest = []
parts.each do |part|
  if part.start_with?('description:')
    new_rest << part.sub(/^description:/, '')
  elsif part.include?(':')
    k, v = part.split(':', 2)
    pairs[k] = v
  else
    new_rest << part
  end
end
rest = new_rest.join(' ')
  current_tags << { type: :response_header, status: status, name: name, schema_type: schema_type, options: pairs, description: rest.strip }
elsif comment =~ /#\s*@link\s+(\d+|default)\s+(\w+)(?:\s+(.*))?/
  status = $1
  name = $2
  rest = $3 || ""
  pairs = {}
  parts = rest.split(' ')
  new_rest = []
  parts.each do |part|
    if part.start_with?('description:')
      new_rest << part.sub(/^description:/, '')
    elsif part.include?(':')
      k, v = part.split(':', 2)
      pairs[k] = v
    else
      new_rest << part
    end
  end
  current_tags << { type: :link, status: status, name: name, options: pairs, description: new_rest.join(' ').strip }
elsif comment =~ /#\s*@param_ref\s+(\w+)/
  current_tags << { type: :param_ref, name: $1.strip }
elsif comment =~ /#\s*@response_ref\s+(\d+|default)\s+(\w+)/
  current_tags << { type: :response_ref, status: $1, name: $2.strip }
elsif comment =~ /#\s*@component_param\s+(\w+)\s+\[(\w+)\]\s+in:(\w+)(?:\s+(.*))?/
  param_name = $1
  schema_type = $2
  loc = $3
  rest = $4 || ""
  pairs = {}
parts = rest.split(' ')
new_rest = []
parts.each do |part|
  if part.start_with?('description:')
    new_rest << part.sub(/^description:/, '')
  elsif part.include?(':')
    k, v = part.split(':', 2)
    pairs[k] = v
  else
    new_rest << part
  end
end
rest = new_rest.join(' ')
  p = {
    "name" => param_name,
    "in" => loc,
    "schema" => (%w[string number integer boolean array object].include?(schema_type.downcase) ? { "type" => schema_type.downcase } : { "$ref" => "#/components/schemas/#{schema_type}" })
  }
  pairs.each do |k, v|
    p[k] = (v == 'true' ? true : (v == 'false' ? false : v))
  end
  p["description"] = rest.strip unless rest.strip.empty?
  ir.openapi_spec["components"] ||= {}
  ir.openapi_spec["components"]["parameters"] ||= {}
  ir.openapi_spec["components"]["parameters"][param_name] = p
elsif comment =~ /#\s*@component_request_body\s+(\w+)\s+\[(\w+)\]\s+(\S+)(?:\s+(.*))?/
  rb_name = $1
  schema_name = $2
  media_type = $3
  rest = $4 || ""
  pairs = {}
  parts = rest.split(' ')
  new_rest = []
  parts.each do |part|
    if part.start_with?('description:')
      new_rest << part.sub(/^description:/, '')
    elsif part.include?(':')
      k, v = part.split(':', 2)
      pairs[k] = v
    else
      new_rest << part
    end
  end
  rb = {
    "content" => {
      media_type => {
        "schema" => { "$ref" => "#/components/schemas/#{schema_name}" }
      }
    }
  }
  pairs.each do |k, v|
    rb[k] = (v == 'true' ? true : (v == 'false' ? false : v))
  end
  rb["description"] = new_rest.join(' ').strip unless new_rest.empty?
  ir.openapi_spec["components"] ||= {}
  ir.openapi_spec["components"]["requestBodies"] ||= {}
  ir.openapi_spec["components"]["requestBodies"][rb_name] = rb
elsif comment =~ /#\s*@request_body_ref\s+(\w+)/
  current_tags << { type: :request_body_ref, name: $1.strip }
elsif comment =~ /#\s*@component_header\s+(\w+)\s+\[(\w+)\](?:\s+(.*))?/
  h_name = $1
  schema_type = $2
  rest = $3 || ""
  pairs = {}
  parts = rest.split(' ')
  new_rest = []
  parts.each do |part|
    if part.start_with?('description:')
      new_rest << part.sub(/^description:/, '')
    elsif part.include?(':')
      k, v = part.split(':', 2)
      pairs[k] = v
    else
      new_rest << part
    end
  end
  h = {
    "schema" => (%w[string number integer boolean array object].include?(schema_type.downcase) ? { "type" => schema_type.downcase } : { "$ref" => "#/components/schemas/#{schema_type}" })
  }
  pairs.each do |k, v|
    h[k] = (v == 'true' ? true : (v == 'false' ? false : v))
  end
  h["description"] = new_rest.join(' ').strip unless new_rest.empty?
  ir.openapi_spec["components"] ||= {}
  ir.openapi_spec["components"]["headers"] ||= {}
  ir.openapi_spec["components"]["headers"][h_name] = h
elsif comment =~ /#\s*@response_header_ref\s+(\d+|default)\s+([A-Za-z0-9_-]+)\s+(\w+)/
  current_tags << { type: :response_header_ref, status: $1, name: $2, ref_name: $3 }
elsif comment =~ /#\s*@component_link\s+(\w+)(?:\s+(.*))?/
  l_name = $1
  rest = $2 || ""
  pairs = {}
  parts = rest.split(' ')
  new_rest = []
  parts.each do |part|
    if part.start_with?('description:')
      new_rest << part.sub(/^description:/, '')
    elsif part.include?(':')
      k, v = part.split(':', 2)
      pairs[k] = v
    else
      new_rest << part
    end
  end
  l = {}
  pairs.each do |k, v|
    if k.include?('.')
      main_k, sub_k = k.split('.', 2)
      l[main_k] ||= {}
      l[main_k][sub_k] = v
    else
      l[k] = v
    end
  end
  l["description"] = new_rest.join(' ').strip unless new_rest.empty?
  ir.openapi_spec["components"] ||= {}
  ir.openapi_spec["components"]["links"] ||= {}
  ir.openapi_spec["components"]["links"][l_name] = l
elsif comment =~ /#\s*@component_callback\s+(\w+)\s+(\S+)\s+(get|put|post|delete|options|head|patch|trace|query)/i
  name, url, method = $1, $2, $3.downcase
  ir.openapi_spec["components"] ||= {}
  ir.openapi_spec["components"]["callbacks"] ||= {}
  ir.openapi_spec["components"]["callbacks"][name] ||= {}
  ir.openapi_spec["components"]["callbacks"][name][url] ||= {}
  ir.openapi_spec["components"]["callbacks"][name][url][method] ||= { "responses" => { "200" => { "description" => "OK" } } }
elsif comment =~ /#\s*@component_callback_request_body\s+\[(\w+)\]\s+(\S+)(?:\s+(.*))?/
  schema_name, media_type, rest = $1, $2, ($3 || "").strip
  if ir.openapi_spec.dig("components", "callbacks")
    cb_name = ir.openapi_spec["components"]["callbacks"].keys.last
    cb_url = ir.openapi_spec["components"]["callbacks"][cb_name].keys.last
    cb_method = ir.openapi_spec["components"]["callbacks"][cb_name][cb_url].keys.last
    rb = { "content" => { media_type => { "schema" => { "$ref" => "#/components/schemas/#{schema_name}" } } } }
    rb["description"] = rest unless rest.empty?
    ir.openapi_spec["components"]["callbacks"][cb_name][cb_url][cb_method]["requestBody"] = rb
  end
elsif comment =~ /#\s*@component_callback_response\s+(\d+|default)(?:\s+\[(\w+)\]\s+(\S+))?(?:\s+(.*))?/
  status, schema_name, media_type, rest = $1, $2, $3, ($4 || "")
  if ir.openapi_spec.dig("components", "callbacks")
    cb_name = ir.openapi_spec["components"]["callbacks"].keys.last
    cb_url = ir.openapi_spec["components"]["callbacks"][cb_name].keys.last
    cb_method = ir.openapi_spec["components"]["callbacks"][cb_name][cb_url].keys.last
    
    parts = rest.split(' ')
    new_rest = []
    pairs = {}
    parts.each do |part|
      if part.start_with?('description:')
        new_rest << part.sub(/^description:/, '')
      elsif part.include?(':')
        k, v = part.split(':', 2)
        pairs[k] = v
      else
        new_rest << part
      end
    end
    
    resp = { "description" => new_rest.empty? ? "Response" : new_rest.join(' ').strip }
    if media_type && schema_name
      resp["content"] = { media_type => { "schema" => { "$ref" => "#/components/schemas/#{schema_name}" } } }
      pairs.each { |k, v| resp["content"][media_type][k] = (v == 'true' ? true : (v == 'false' ? false : v)) }
    else
      pairs.each { |k, v| resp[k] = (v == 'true' ? true : (v == 'false' ? false : v)) }
    end
    ir.openapi_spec["components"]["callbacks"][cb_name][cb_url][cb_method]["responses"][status] = resp
  end
elsif comment =~ /#\s*@callback_ref\s+(\w+)\s+(\w+)/
  current_tags << { type: :callback_ref, name: $1, ref_name: $2 }
            elsif comment =~ /#\s*@link_ref\s+(\d+|default)\s+(\w+)\s+(\w+)/
  current_tags << { type: :link_ref, status: $1, name: $2, ref_name: $3 }
            elsif comment =~ /#\s*@component_response\s+(\w+)(?:\s+\[(\w+)\]\s+(\S+))?(?:\s+(.*))?/

  resp_name = $1
  schema_name = $2
  media_type = $3
  rest = $4 || ""
  pairs = {}
  parts = rest.split(' ')
  new_rest = []
  parts.each do |part|
    if part.start_with?('description:')
      new_rest << part.sub(/^description:/, '')
    elsif part.include?(':')
      k, v = part.split(':', 2)
      pairs[k] = v
    else
      new_rest << part
    end
  end
  resp = {
    "description" => new_rest.empty? ? "Response" : new_rest.join(' ').strip
  }
  if media_type && schema_name
    resp["content"] = {
      media_type => {
        "schema" => { "$ref" => "#/components/schemas/#{schema_name}" }
      }
    }
    pairs.each do |k, v|
      val = (v == 'true' ? true : (v == 'false' ? false : v))
      resp["content"][media_type][k] = val
    end
  else
    pairs.each do |k, v|
      val = (v == 'true' ? true : (v == 'false' ? false : v))
      resp[k] = val
    end
  end
  ir.openapi_spec["components"] ||= {}
  ir.openapi_spec["components"]["responses"] ||= {}
  ir.openapi_spec["components"]["responses"][resp_name] = resp
elsif comment =~ /#\s*@summary\s+(.*)/

              current_tags << { type: :summary, value: $1.strip }
            elsif comment =~ /#\s*@description\s+(.*)/
              current_tags << { type: :description, value: $1.strip }
            elsif comment =~ /#\s*@deprecated/
              current_tags << { type: :deprecated }
            elsif comment =~ /#\s*@external_docs\s+(\S+)(?:\s+(.*))?/
              current_tags << { type: :external_docs, url: $1.strip, description: $2 ? $2.strip : nil }
            elsif comment =~ /#\s*@op_server\s+(\S+)(?:\s+(.*))?/
              current_tags << { type: :op_server, url: $1.strip, description: $2 ? $2.strip : nil }
            elsif comment =~ /#\s*@path_summary\s+(.*)/
              current_tags << { type: :path_summary, value: $1.strip }
            elsif comment =~ /#\s*@path_description\s+(.*)/
              current_tags << { type: :path_description, value: $1.strip }
            elsif comment =~ /#\s*@(route|webhook)\s+([A-Z]+)\s+(\S+)/i
  is_webhook = ($1.downcase == "webhook")
  method = $2.downcase
  path = $3
  if is_webhook
    ir.openapi_spec["webhooks"] ||= {}
    ir.openapi_spec["webhooks"][path] ||= {}
  else
    ir.openapi_spec["paths"] ||= {}
    ir.openapi_spec["paths"][path] ||= {}
  end

              
              op = { "responses" => { "200" => { "description" => "OK" } } }
              
              params = []
              security = []
              tags = []
              servers = []
              
              current_tags.each do |tag|
                if tag[:type] == :param
                  p = {
                    "name" => tag[:name],
                    "in" => tag[:in],
                    "schema" => (%w[string number integer boolean array object].include?(tag[:schema_type].downcase) ? { "type" => tag[:schema_type].downcase } : { "$ref" => "#/components/schemas/#{tag[:schema_type]}" })
                  }
                  tag[:options].each do |k, v|
                    if v == 'true'
                      p[k] = true
                    elsif v == 'false'
                      p[k] = false
                    else
                      p[k] = v
                    end
                  end
                  p["description"] = tag[:description] if tag[:description] && !tag[:description].empty?
                  params << p
                elsif tag[:type] == :op_server_var
  server = servers.find { |s| s["url"] == tag[:url] }
  unless server
    server = { "url" => tag[:url] }
    servers << server
  end
  server["variables"] ||= {}
  pairs = {}
  parts = tag[:rest].split(' ')
  new_rest = []
  parts.each do |part|
    if part.start_with?('description:')
      new_rest << part.sub(/^description:/, '')
    elsif part.include?(':')
      k, v = part.split(':', 2)
      pairs[k] = v
    else
      new_rest << part
    end
  end
  var_obj = { "default" => tag[:default_val] }
  var_obj["enum"] = pairs["enum"].split(',') if pairs["enum"]
  var_obj["description"] = new_rest.join(' ').strip unless new_rest.empty?
  server["variables"][tag[:var_name]] = var_obj
elsif tag[:type] == :param_example_ref
  p = params.find { |param| param["name"] == tag[:param_name] }
  if p
    p["examples"] ||= {}
    p["examples"][tag[:example_name]] = { "$ref" => "#/components/examples/#{tag[:ref_name]}" }
  end
elsif tag[:type] == :request_body_example_ref
  if op["requestBody"] && op["requestBody"]["content"] && op["requestBody"]["content"][tag[:media_type]]
    op["requestBody"]["content"][tag[:media_type]]["examples"] ||= {}
    op["requestBody"]["content"][tag[:media_type]]["examples"][tag[:example_name]] = { "$ref" => "#/components/examples/#{tag[:ref_name]}" }
  end
elsif tag[:type] == :response_example_ref
  if op["responses"][tag[:status]] && op["responses"][tag[:status]]["content"] && op["responses"][tag[:status]]["content"][tag[:media_type]]
    op["responses"][tag[:status]]["content"][tag[:media_type]]["examples"] ||= {}
    op["responses"][tag[:status]]["content"][tag[:media_type]]["examples"][tag[:example_name]] = { "$ref" => "#/components/examples/#{tag[:ref_name]}" }
  end
                elsif tag[:type] == :request_body
                  rb = {
                    "content" => {
                      tag[:media_type] => {
                        "schema" => { "$ref" => "#/components/schemas/#{tag[:schema_name]}" }
                      }
                    }
                  }
                  tag[:options].each do |k, v|
                    if v == 'true'
                      rb[k] = true
                    elsif v == 'false'
                      rb[k] = false
                    else
                      rb[k] = v
                    end
                  end
                  rb["description"] = tag[:description] if tag[:description] && !tag[:description].empty?
                  op["requestBody"] = rb
                elsif tag[:type] == :param_ref
  params << { "$ref" => "#/components/parameters/#{tag[:name]}" }
elsif tag[:type] == :request_body_encoding
  if op["requestBody"] && op["requestBody"]["content"] && op["requestBody"]["content"][tag[:media_type]]
    op["requestBody"]["content"][tag[:media_type]]["encoding"] ||= {}
    enc = {}
    tag[:options].each do |k, v|
      enc[k] = (v == 'true' ? true : (v == 'false' ? false : v))
    end
    enc["description"] = tag[:description] if tag[:description] && !tag[:description].empty?
    op["requestBody"]["content"][tag[:media_type]]["encoding"][tag[:property]] = enc
  end
elsif tag[:type] == :response_ref
  op["responses"][tag[:status]] = { "$ref" => "#/components/responses/#{tag[:name]}" }
elsif tag[:type] == :request_body_ref
  op["requestBody"] = { "$ref" => "#/components/requestBodies/#{tag[:name]}" }
elsif tag[:type] == :response_header_ref
  op["responses"][tag[:status]] ||= { "description" => "Response" }
  op["responses"][tag[:status]]["headers"] ||= {}
  op["responses"][tag[:status]]["headers"][tag[:name]] = { "$ref" => "#/components/headers/#{tag[:ref_name]}" }
elsif tag[:type] == :link_ref
  op["responses"][tag[:status]] ||= { "description" => "Response" }
  op["responses"][tag[:status]]["links"] ||= {}
  op["responses"][tag[:status]]["links"][tag[:name]] = { "$ref" => "#/components/links/#{tag[:ref_name]}" }
                elsif tag[:type] == :response_header

  op["responses"][tag[:status]] ||= { "description" => "Response" }
  op["responses"][tag[:status]]["headers"] ||= {}
  h = {
    "schema" => (%w[string number integer boolean array object].include?(tag[:schema_type].downcase) ? { "type" => tag[:schema_type].downcase } : { "$ref" => "#/components/schemas/#{tag[:schema_type]}" })
  }
  h["description"] = tag[:description] if tag[:description] && !tag[:description].empty?
  tag[:options].each do |k, v|
    h[k] = (v == 'true' ? true : (v == 'false' ? false : v))
  end
  op["responses"][tag[:status]]["headers"][tag[:name]] = h
elsif tag[:type] == :link
  op["responses"][tag[:status]] ||= { "description" => "Response" }
  op["responses"][tag[:status]]["links"] ||= {}
  l = {}
  l["description"] = tag[:description] if tag[:description] && !tag[:description].empty?
  tag[:options].each do |k, v|
    if k.include?('.')
      main_k, sub_k = k.split('.', 2)
      l[main_k] ||= {}
      l[main_k][sub_k] = v
    else
      l[k] = v
    end
  end
  op["responses"][tag[:status]]["links"][tag[:name]] = l
elsif tag[:type] == :response

                  resp = {
                    "description" => (tag[:description] && !tag[:description].empty?) ? tag[:description].strip : "Response"
                  }
                  if tag[:media_type] && tag[:schema_name]
                    resp["content"] = {
                      tag[:media_type] => {
                        "schema" => { "$ref" => "#/components/schemas/#{tag[:schema_name]}" }
                      }
                    }
                  end
                  if tag[:options]
                    tag[:options].each do |k, v|
                      if v == 'true'
                        v = true
                      elsif v == 'false'
                        v = false
                      end
                      if tag[:media_type]
                        resp["content"][tag[:media_type]][k] = v
                      else
                        resp[k] = v
                      end
                    end
                  end
                  op["responses"][tag[:status]] = resp
                elsif tag[:type] == :security
                  if tag[:scheme]
                    security << { tag[:scheme] => tag[:scopes] }
                  else
                    security << {}
                  end
                elsif tag[:type] == :callback
                  op["callbacks"] ||= {}
                  op["callbacks"][tag[:name]] ||= {}
                  op["callbacks"][tag[:name]][tag[:url]] ||= {}
                  op["callbacks"][tag[:name]][tag[:url]][tag[:method]] ||= { "responses" => { "200" => { "description" => "OK" } } }
                elsif tag[:type] == :callback_ref
  op["callbacks"] ||= {}
  op["callbacks"][tag[:name]] = { "$ref" => "#/components/callbacks/#{tag[:ref_name]}" }
elsif tag[:type] == :callback_request_body

                  if op["callbacks"]
                    cb_name = op["callbacks"].keys.last
                    cb_url = op["callbacks"][cb_name].keys.last
                    cb_method = op["callbacks"][cb_name][cb_url].keys.last
                    
                    rb = {
                      "content" => {
                        tag[:media_type] => {
                          "schema" => { "$ref" => "#/components/schemas/#{tag[:schema_name]}" }
                        }
                      }
                    }
                    rb["description"] = tag[:description] if tag[:description] && !tag[:description].empty?
                    op["callbacks"][cb_name][cb_url][cb_method]["requestBody"] = rb
                  end
                elsif tag[:type] == :callback_response
                  if op["callbacks"]
                    cb_name = op["callbacks"].keys.last
                    cb_url = op["callbacks"][cb_name].keys.last
                    cb_method = op["callbacks"][cb_name][cb_url].keys.last
                    
                    resp = {
                      "description" => (tag[:description] && !tag[:description].empty?) ? tag[:description].strip : "Response"
                    }
                    if tag[:media_type] && tag[:schema_name]
                      resp["content"] = {
                        tag[:media_type] => {
                          "schema" => { "$ref" => "#/components/schemas/#{tag[:schema_name]}" }
                        }
                      }
                    end
                    if tag[:options]
                      tag[:options].each do |k, v|
                        if v == 'true'
                          v = true
                        elsif v == 'false'
                          v = false
                        end
                        if tag[:media_type]
                          resp["content"][tag[:media_type]][k] = v
                        else
                          resp[k] = v
                        end
                      end
                    end
                    op["callbacks"][cb_name][cb_url][cb_method]["responses"][tag[:status]] = resp
                  end
                elsif tag[:type] == :operationId
                  op["operationId"] = tag[:value]
                elsif tag[:type] == :tag
                  tags << tag[:value]
                elsif tag[:type] == :summary
                  op["summary"] = tag[:value]
                elsif tag[:type] == :description
                  op["description"] = tag[:value]
                elsif tag[:type] == :deprecated
                  op["deprecated"] = true
                elsif tag[:type] == :external_docs
                  ed = { "url" => tag[:url] }
                  ed["description"] = tag[:description] if tag[:description] && !tag[:description].empty?
                  op["externalDocs"] = ed
                elsif tag[:type] == :op_server
                  srv = { "url" => tag[:url] }
                  srv["description"] = tag[:description] if tag[:description] && !tag[:description].empty?
                  servers << srv
                elsif tag[:type] == :path_summary
                  ir.openapi_spec["paths"][path]["summary"] = tag[:value]
                elsif tag[:type] == :path_description
                  ir.openapi_spec["paths"][path]["description"] = tag[:value]
                end
              end
              
              # Auto-extract path parameters from the path string (e.g. /users/{id})
              path.scan(/\{(\w+)\}/).flatten.each do |path_param|
                unless params.any? { |p| p["name"] == path_param && p["in"] == "path" }
                  params << {
                    "name" => path_param,
                    "in" => "path",
                    "required" => true,
                    "schema" => { "type" => "string" },
                    "description" => "Auto-extracted path parameter"
                  }
                end
              end

              op["parameters"] = params unless params.empty?
              op["security"] = security unless security.empty?
              op["tags"] = tags unless tags.empty?
              op["servers"] = servers unless servers.empty?
              
              if is_webhook
  ir.openapi_spec["webhooks"][path][method] = op
else
  ir.openapi_spec["paths"][path][method] = op
end
current_tags.clear

            end
          elsif token[1] == :on_sp || token[1] == :on_nl || token[1] == :on_ignored_nl
            # ignore whitespace
          else
            # Clear tags if we hit code that isn't a route (simplification)
            current_tags.clear
          end
        end
      end
    end
  end
end
