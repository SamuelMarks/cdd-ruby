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
            case comment
            when /#\s*@server\s+(\S+)\s*(.*)/
              ir.openapi_spec['servers'] ||= []
              ir.openapi_spec['servers'] << { 'url' => ::Regexp.last_match(1),
                                              'description' => ::Regexp.last_match(2).strip }
            when /#\s*@server_var\s+(\S+)\s+(\w+)\s+(\S+)(?:\s+(.*))?/
              url = ::Regexp.last_match(1)
              var_name = ::Regexp.last_match(2)
              default_val = ::Regexp.last_match(3)
              rest = ::Regexp.last_match(4) || ''
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
              server = (ir.openapi_spec['servers'] ||= []).find { |s| s['url'] == url }
              if server
                server['variables'] ||= {}
                var_obj = { 'default' => default_val }
                var_obj['enum'] = pairs['enum'].split(',') if pairs['enum']
                var_obj['description'] = new_rest.join(' ').strip unless new_rest.empty?
                server['variables'][var_name] = var_obj
              end
            when /#\s*@op_server_var\s+(\S+)\s+(\w+)\s+(\S+)(?:\s+(.*))?/
              url = ::Regexp.last_match(1)
              var_name = ::Regexp.last_match(2)
              default_val = ::Regexp.last_match(3)
              rest = ::Regexp.last_match(4) || ''
              current_tags << { type: :op_server_var, url: url, var_name: var_name, default_val: default_val,
                                rest: rest }
            when /#\s*@route_ref\s+(\S+)\s+(\w+)/
              ir.openapi_spec['paths'] ||= {}
              ir.openapi_spec['paths'][::Regexp.last_match(1)] =
                { '$ref' => "#/components/pathItems/#{::Regexp.last_match(2)}" }
            when /#\s*@param_example_ref\s+(\w+)\s+(\w+)\s+(\w+)/
              current_tags << { type: :param_example_ref, param_name: ::Regexp.last_match(1),
                                example_name: ::Regexp.last_match(2), ref_name: ::Regexp.last_match(3) }
            when /#\s*@request_body_example_ref\s+(\S+)\s+(\w+)\s+(\w+)/
              current_tags << { type: :request_body_example_ref, media_type: ::Regexp.last_match(1),
                                example_name: ::Regexp.last_match(2), ref_name: ::Regexp.last_match(3) }
            when /#\s*@response_example_ref\s+(\d+|default)\s+(\S+)\s+(\w+)\s+(\w+)/
              current_tags << { type: :response_example_ref, status: ::Regexp.last_match(1),
                                media_type: ::Regexp.last_match(2), example_name: ::Regexp.last_match(3), ref_name: ::Regexp.last_match(4) }
            when /#\s*@security_scheme\s+(\w+)\s+(\w+)(?:\s+(.*))?/
              scheme_name = ::Regexp.last_match(1)
              type = ::Regexp.last_match(2)
              rest = ::Regexp.last_match(3) || ''
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
              ir.openapi_spec['components'] ||= {}
              ir.openapi_spec['components']['securitySchemes'] ||= {}
              scheme = { 'type' => type }
              pairs.each { |k, v| scheme[k] = v }
              scheme['description'] = rest.strip unless rest.strip.empty?
              ir.openapi_spec['components']['securitySchemes'][scheme_name] = scheme
            when /#\s*@security\b(?:\s+(\w+))?(?:\s+(.*))?/
              scheme = ::Regexp.last_match(1)
              scopes = ::Regexp.last_match(2) ? ::Regexp.last_match(2).split(/\s*,\s*/) : []
              current_tags << if scheme
                                { type: :security, scheme: scheme, scopes: scopes }
                              else
                                { type: :security, scheme: nil, scopes: [] }
                              end
            when /#\s*@schema_xml\s+(\w+)(?:\s+(.*))?/
              schema_name = ::Regexp.last_match(1)
              rest = ::Regexp.last_match(2) || ''
              pairs = {}
              while rest =~ /^([a-zA-Z]+):(\S+)\s+(.*)$/
                pairs[::Regexp.last_match(1)] = ::Regexp.last_match(2)
                rest = ::Regexp.last_match(3)
              end
              if rest =~ /^([a-zA-Z]+):(\S+)$/
                pairs[::Regexp.last_match(1)] = ::Regexp.last_match(2)
                ''
              end
              ir.openapi_spec['components'] ||= {}
              ir.openapi_spec['components']['schemas'] ||= {}
              ir.openapi_spec['components']['schemas'][schema_name] ||= { 'type' => 'object' }
              ir.openapi_spec['components']['schemas'][schema_name]['xml'] ||= {}
              pairs.each do |k, v|
                val = (if v == 'true'
                         true
                       else
                         (v == 'false' ? false : v)
                       end)
                ir.openapi_spec['components']['schemas'][schema_name]['xml'][k] = val
              end
            when /#\s*@schema_one_of\s+(\w+)\s+(.*)/

              schema_name = ::Regexp.last_match(1)
              rest = ::Regexp.last_match(2)
              # Check for discriminator mapping format: Base Type1:Dog,Type2:Cat
              if rest =~ /^([a-zA-Z0-9_,\s]+)\s+discriminator:(\w+)(?:\s+mapping:([^\s]+))?(?:\s+defaultMapping:(\w+))?$/
                match_data = Regexp.last_match.dup

                refs_str = match_data[1]
                prop = match_data[2]
                mapping_str = match_data[3]
                dm_str = match_data[4]

                refs = refs_str.split(/\s*,\s*/).map { |r| { '$ref' => "#/components/schemas/#{r}" } }
                schema = { 'oneOf' => refs, 'discriminator' => { 'propertyName' => prop } }
                if mapping_str
                  mapping = {}
                  mapping_str.split(/\s*,\s*/).each do |pair|
                    k, v = pair.split(':')
                    mapping[k] = "#/components/schemas/#{v}"
                  end
                  schema['discriminator']['mapping'] = mapping
                end
                if dm_str
                  schema['discriminator']['defaultMapping'] =
                    "#/components/schemas/#{dm_str}"
                end

                ir.openapi_spec['components'] ||= {}
                ir.openapi_spec['components']['schemas'] ||= {}
                ir.openapi_spec['components']['schemas'][schema_name] = schema
              else
                refs = (rest || '').to_s.split(/\s*,\s*/).map do |r|
                  { '$ref' => "#/components/schemas/#{r}" }
                end
                ir.openapi_spec['components'] ||= {}
                ir.openapi_spec['components']['schemas'] ||= {}
                ir.openapi_spec['components']['schemas'][schema_name] ||= { 'oneOf' => refs }
              end
            when /#\s*@schema_any_of\s+(\w+)\s+(.*)/
              schema_name = ::Regexp.last_match(1)
              rest = ::Regexp.last_match(2)
              if rest =~ /^([a-zA-Z0-9_,\s]+)\s+discriminator:(\w+)(?:\s+mapping:([^\s]+))?(?:\s+defaultMapping:(\w+))?$/
                match_data = Regexp.last_match.dup
                refs_str = match_data[1]
                prop = match_data[2]
                mapping_str = match_data[3]
                dm_str = match_data[4]
                refs = refs_str.split(/\s*,\s*/).map { |r| { '$ref' => "#/components/schemas/#{r}" } }
                schema = { 'anyOf' => refs, 'discriminator' => { 'propertyName' => prop } }
                if mapping_str
                  mapping = {}
                  mapping_str.split(/\s*,\s*/).each do |pair|
                    k, v = pair.split(':')
                    mapping[k] = "#/components/schemas/#{v}"
                  end
                  schema['discriminator']['mapping'] = mapping
                end
                schema['discriminator']['defaultMapping'] = "#/components/schemas/#{dm_str}" if dm_str
                ir.openapi_spec['components'] ||= {}
                ir.openapi_spec['components']['schemas'] ||= {}
                ir.openapi_spec['components']['schemas'][schema_name] = schema
              else
                refs = rest.split(/\s*,\s*/).map { |r| { '$ref' => "#/components/schemas/#{r}" } }
                ir.openapi_spec['components'] ||= {}
                ir.openapi_spec['components']['schemas'] ||= {}
                ir.openapi_spec['components']['schemas'][schema_name] ||= { 'anyOf' => refs }
              end

            when /#\s*@schema\s+(\w+)(?:\s+(.*))?/
              schema_name = ::Regexp.last_match(1)
              rest = ::Regexp.last_match(2) || ''
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
              ir.openapi_spec['components'] ||= {}
              ir.openapi_spec['components']['schemas'] ||= {}
              ir.openapi_spec['components']['schemas'][schema_name] ||= { 'type' => 'object', 'properties' => {} }
              pairs.each { |k, v| ir.openapi_spec['components']['schemas'][schema_name][k] = v }
              ir.openapi_spec['components']['schemas'][schema_name]['description'] = rest.strip unless rest.strip.empty?
            when /#\s*@param\s+(\w+)\s+\[(\w+)\]\s+in:(\w+)(?:\s+(.*))?/
              name = ::Regexp.last_match(1)
              schema_type = ::Regexp.last_match(2)
              loc = ::Regexp.last_match(3)
              rest = ::Regexp.last_match(4) || ''
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
              current_tags << { type: :param, name: name, schema_type: schema_type, in: loc, options: pairs,
                                description: rest.strip }
            when /#\s*@request_body_encoding\s+(\S+)\s+(\S+)(?:\s+(.*))?/
              media_type = ::Regexp.last_match(1)
              property = ::Regexp.last_match(2)
              rest = ::Regexp.last_match(3) || ''
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
              current_tags << { type: :request_body_encoding, media_type: media_type, property: property, options: pairs,
                                description: new_rest.join(' ').strip }
            when /#\s*@request_body\s+\[(\w+)\]\s+(\S+)(?:\s+(.*))?/
              schema_name = ::Regexp.last_match(1)
              media_type = ::Regexp.last_match(2)
              rest = ::Regexp.last_match(3) || ''
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
              current_tags << { type: :request_body, schema_name: schema_name, media_type: media_type, options: pairs,
                                description: rest.strip }
            when /#\s*@response\s+(\d+|default)(?:\s+\[(\w+)\]\s+(\S+))?(?:\s+(.*))?/
              status = ::Regexp.last_match(1)
              schema_name = ::Regexp.last_match(2)
              media_type = ::Regexp.last_match(3)
              rest = ::Regexp.last_match(4) || ''
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
              current_tags << { type: :response, status: status, schema_name: schema_name, media_type: media_type,
                                options: pairs, description: new_rest.join(' ').strip }
            when /#\s*@operationId\s+(.*)/
              current_tags << { type: :operationId, value: ::Regexp.last_match(1).strip }
            when /#\s*@tag\s+(.*)/
              current_tags << { type: :tag, value: ::Regexp.last_match(1).strip }
            when /#\s*@callback\s+(\w+)\s+(\S+)\s+(get|put|post|delete|options|head|patch|trace|query)/i
              current_tags << { type: :callback, name: ::Regexp.last_match(1), url: ::Regexp.last_match(2),
                                method: ::Regexp.last_match(3).downcase }
            when /#\s*@callback_request_body\s+\[(\w+)\]\s+(\S+)(?:\s+(.*))?/
              current_tags << { type: :callback_request_body, schema_name: ::Regexp.last_match(1), media_type: ::Regexp.last_match(2),
                                description: ::Regexp.last_match(3)&.strip }
            when /#\s*@callback_response\s+(\d+|default)(?:\s+\[(\w+)\]\s+(\S+))?(?:\s+(.*))?/
              status = ::Regexp.last_match(1)
              schema_name = ::Regexp.last_match(2)
              media_type = ::Regexp.last_match(3)
              rest = ::Regexp.last_match(4) || ''
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
              current_tags << { type: :callback_response, status: status, schema_name: schema_name,
                                media_type: media_type, options: pairs, description: new_rest.join(' ').strip }
            when /#\s*@response_header\s+(\d+|default)\s+([A-Za-z0-9_-]+)\s+\[(\w+)\](?:\s+(.*))?/
              status = ::Regexp.last_match(1)
              name = ::Regexp.last_match(2)
              schema_type = ::Regexp.last_match(3)
              rest = ::Regexp.last_match(4) || ''
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
              current_tags << { type: :response_header, status: status, name: name, schema_type: schema_type, options: pairs,
                                description: rest.strip }
            when /#\s*@link\s+(\d+|default)\s+(\w+)(?:\s+(.*))?/
              status = ::Regexp.last_match(1)
              name = ::Regexp.last_match(2)
              rest = ::Regexp.last_match(3) || ''
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
              current_tags << { type: :link, status: status, name: name, options: pairs,
                                description: new_rest.join(' ').strip }
            when /#\s*@param_ref\s+(\w+)/
              current_tags << { type: :param_ref, name: ::Regexp.last_match(1).strip }
            when /#\s*@response_ref\s+(\d+|default)\s+(\w+)/
              current_tags << { type: :response_ref, status: ::Regexp.last_match(1),
                                name: ::Regexp.last_match(2).strip }
            when /#\s*@component_param\s+(\w+)\s+\[(\w+)\]\s+in:(\w+)(?:\s+(.*))?/
              param_name = ::Regexp.last_match(1)
              schema_type = ::Regexp.last_match(2)
              loc = ::Regexp.last_match(3)
              rest = ::Regexp.last_match(4) || ''
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
                'name' => param_name,
                'in' => loc,
                'schema' => (if %w[string number integer boolean array
                                   object].include?(schema_type.downcase)
                               { 'type' => schema_type.downcase }
                             else
                               { '$ref' => "#/components/schemas/#{schema_type}" }
                             end)
              }
              pairs.each do |k, v|
                p[k] = (if v == 'true'
                          true
                        else
                          (v == 'false' ? false : v)
                        end)
              end
              p['description'] = rest.strip unless rest.strip.empty?
              ir.openapi_spec['components'] ||= {}
              ir.openapi_spec['components']['parameters'] ||= {}
              ir.openapi_spec['components']['parameters'][param_name] = p
            when /#\s*@component_request_body\s+(\w+)\s+\[(\w+)\]\s+(\S+)(?:\s+(.*))?/
              rb_name = ::Regexp.last_match(1)
              schema_name = ::Regexp.last_match(2)
              media_type = ::Regexp.last_match(3)
              rest = ::Regexp.last_match(4) || ''
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
                'content' => {
                  media_type => {
                    'schema' => { '$ref' => "#/components/schemas/#{schema_name}" }
                  }
                }
              }
              pairs.each do |k, v|
                rb[k] = (if v == 'true'
                           true
                         else
                           (v == 'false' ? false : v)
                         end)
              end
              rb['description'] = new_rest.join(' ').strip unless new_rest.empty?
              ir.openapi_spec['components'] ||= {}
              ir.openapi_spec['components']['requestBodies'] ||= {}
              ir.openapi_spec['components']['requestBodies'][rb_name] = rb
            when /#\s*@request_body_ref\s+(\w+)/
              current_tags << { type: :request_body_ref, name: ::Regexp.last_match(1).strip }
            when /#\s*@component_header\s+(\w+)\s+\[(\w+)\](?:\s+(.*))?/
              h_name = ::Regexp.last_match(1)
              schema_type = ::Regexp.last_match(2)
              rest = ::Regexp.last_match(3) || ''
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
                'schema' => (if %w[string number integer boolean array
                                   object].include?(schema_type.downcase)
                               { 'type' => schema_type.downcase }
                             else
                               { '$ref' => "#/components/schemas/#{schema_type}" }
                             end)
              }
              pairs.each do |k, v|
                h[k] = (if v == 'true'
                          true
                        else
                          (v == 'false' ? false : v)
                        end)
              end
              h['description'] = new_rest.join(' ').strip unless new_rest.empty?
              ir.openapi_spec['components'] ||= {}
              ir.openapi_spec['components']['headers'] ||= {}
              ir.openapi_spec['components']['headers'][h_name] = h
            when /#\s*@response_header_ref\s+(\d+|default)\s+([A-Za-z0-9_-]+)\s+(\w+)/
              current_tags << { type: :response_header_ref, status: ::Regexp.last_match(1),
                                name: ::Regexp.last_match(2), ref_name: ::Regexp.last_match(3) }
            when /#\s*@component_link\s+(\w+)(?:\s+(.*))?/
              l_name = ::Regexp.last_match(1)
              rest = ::Regexp.last_match(2) || ''
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
              l['description'] = new_rest.join(' ').strip unless new_rest.empty?
              ir.openapi_spec['components'] ||= {}
              ir.openapi_spec['components']['links'] ||= {}
              ir.openapi_spec['components']['links'][l_name] = l
            when /#\s*@component_callback\s+(\w+)\s+(\S+)\s+(get|put|post|delete|options|head|patch|trace|query)/i
              name = ::Regexp.last_match(1)
              url = ::Regexp.last_match(2)
              method = ::Regexp.last_match(3).downcase
              ir.openapi_spec['components'] ||= {}
              ir.openapi_spec['components']['callbacks'] ||= {}
              ir.openapi_spec['components']['callbacks'][name] ||= {}
              ir.openapi_spec['components']['callbacks'][name][url] ||= {}
              ir.openapi_spec['components']['callbacks'][name][url][method] ||= { 'responses' => { '200' => { 'description' => 'OK' } } }
            when /#\s*@component_callback_request_body\s+\[(\w+)\]\s+(\S+)(?:\s+(.*))?/
              schema_name = ::Regexp.last_match(1)
              media_type = ::Regexp.last_match(2)
              rest = (::Regexp.last_match(3) || '').strip
              if ir.openapi_spec.dig('components', 'callbacks')
                cb_name = ir.openapi_spec['components']['callbacks'].keys.last
                cb_url = ir.openapi_spec['components']['callbacks'][cb_name].keys.last
                cb_method = ir.openapi_spec['components']['callbacks'][cb_name][cb_url].keys.last
                rb = { 'content' => { media_type => { 'schema' => { '$ref' => "#/components/schemas/#{schema_name}" } } } }
                rb['description'] = rest unless rest.empty?
                ir.openapi_spec['components']['callbacks'][cb_name][cb_url][cb_method]['requestBody'] = rb
              end
            when /#\s*@component_callback_response\s+(\d+|default)(?:\s+\[(\w+)\]\s+(\S+))?(?:\s+(.*))?/
              status = ::Regexp.last_match(1)
              schema_name = ::Regexp.last_match(2)
              media_type = ::Regexp.last_match(3)
              rest = ::Regexp.last_match(4) || ''
              if ir.openapi_spec.dig('components', 'callbacks')
                cb_name = ir.openapi_spec['components']['callbacks'].keys.last
                cb_url = ir.openapi_spec['components']['callbacks'][cb_name].keys.last
                cb_method = ir.openapi_spec['components']['callbacks'][cb_name][cb_url].keys.last

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

                resp = { 'description' => new_rest.empty? ? 'Response' : new_rest.join(' ').strip }
                if media_type && schema_name
                  resp['content'] =
                    { media_type => { 'schema' => { '$ref' => "#/components/schemas/#{schema_name}" } } }
                  pairs.each do |k, v|
                    resp['content'][media_type][k] = (if v == 'true'
                                                        true
                                                      else
                                                        (v == 'false' ? false : v)
                                                      end)
                  end
                else
                  pairs.each do |k, v|
                    resp[k] = (if v == 'true'
                                 true
                               else
                                 (v == 'false' ? false : v)
                               end)
                  end
                end
                ir.openapi_spec['components']['callbacks'][cb_name][cb_url][cb_method]['responses'][status] = resp
              end
            when /#\s*@callback_ref\s+(\w+)\s+(\w+)/
              current_tags << { type: :callback_ref, name: ::Regexp.last_match(1), ref_name: ::Regexp.last_match(2) }
            when /#\s*@link_ref\s+(\d+|default)\s+(\w+)\s+(\w+)/
              current_tags << { type: :link_ref, status: ::Regexp.last_match(1), name: ::Regexp.last_match(2),
                                ref_name: ::Regexp.last_match(3) }
            when /#\s*@component_response\s+(\w+)(?:\s+\[(\w+)\]\s+(\S+))?(?:\s+(.*))?/

              resp_name = ::Regexp.last_match(1)
              schema_name = ::Regexp.last_match(2)
              media_type = ::Regexp.last_match(3)
              rest = ::Regexp.last_match(4) || ''
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
                'description' => new_rest.empty? ? 'Response' : new_rest.join(' ').strip
              }
              if media_type && schema_name
                resp['content'] = {
                  media_type => {
                    'schema' => { '$ref' => "#/components/schemas/#{schema_name}" }
                  }
                }
                pairs.each do |k, v|
                  val = (if v == 'true'
                           true
                         else
                           (v == 'false' ? false : v)
                         end)
                  resp['content'][media_type][k] = val
                end
              else
                pairs.each do |k, v|
                  val = (if v == 'true'
                           true
                         else
                           (v == 'false' ? false : v)
                         end)
                  resp[k] = val
                end
              end
              ir.openapi_spec['components'] ||= {}
              ir.openapi_spec['components']['responses'] ||= {}
              ir.openapi_spec['components']['responses'][resp_name] = resp
            when /#\s*@summary\s+(.*)/

              current_tags << { type: :summary, value: ::Regexp.last_match(1).strip }
            when /#\s*@description\s+(.*)/
              current_tags << { type: :description, value: ::Regexp.last_match(1).strip }
            when /#\s*@deprecated/
              current_tags << { type: :deprecated }
            when /#\s*@external_docs\s+(\S+)(?:\s+(.*))?/
              current_tags << { type: :external_docs, url: ::Regexp.last_match(1).strip,
                                description: ::Regexp.last_match(2)&.strip }
            when /#\s*@op_server\s+(\S+)(?:\s+(.*))?/
              current_tags << { type: :op_server, url: ::Regexp.last_match(1).strip,
                                description: ::Regexp.last_match(2)&.strip }
            when /#\s*@path_summary\s+(.*)/
              current_tags << { type: :path_summary, value: ::Regexp.last_match(1).strip }
            when /#\s*@path_description\s+(.*)/
              current_tags << { type: :path_description, value: ::Regexp.last_match(1).strip }
            when /#\s*@(route|webhook)\s+([A-Z]+)\s+(\S+)/i
              is_webhook = (::Regexp.last_match(1).downcase == 'webhook')
              method = ::Regexp.last_match(2).downcase
              path = ::Regexp.last_match(3)
              if is_webhook
                ir.openapi_spec['webhooks'] ||= {}
                ir.openapi_spec['webhooks'][path] ||= {}
              else
                ir.openapi_spec['paths'] ||= {}
                ir.openapi_spec['paths'][path] ||= {}
              end

              op = { 'responses' => { '200' => { 'description' => 'OK' } } }

              params = []
              security = []
              tags = []
              servers = []

              current_tags.each do |tag|
                case tag[:type]
                when :param
                  p = {
                    'name' => tag[:name],
                    'in' => tag[:in],
                    'schema' => (if %w[string number integer boolean array
                                       object].include?(tag[:schema_type].downcase)
                                   { 'type' => tag[:schema_type].downcase }
                                 else
                                   { '$ref' => "#/components/schemas/#{tag[:schema_type]}" }
                                 end)
                  }
                  tag[:options].each do |k, v|
                    p[k] = if v == 'true'
                             true
                           elsif v == 'false'
                             false
                           else
                             v
                           end
                  end
                  p['description'] = tag[:description] if tag[:description] && !tag[:description].empty?
                  params << p
                when :op_server_var
                  server = servers.find { |s| s['url'] == tag[:url] }
                  unless server
                    server = { 'url' => tag[:url] }
                    servers << server
                  end
                  server['variables'] ||= {}
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
                  var_obj = { 'default' => tag[:default_val] }
                  var_obj['enum'] = pairs['enum'].split(',') if pairs['enum']
                  var_obj['description'] = new_rest.join(' ').strip unless new_rest.empty?
                  server['variables'][tag[:var_name]] = var_obj
                when :param_example_ref
                  p = params.find { |param| param['name'] == tag[:param_name] }
                  if p
                    p['examples'] ||= {}
                    p['examples'][tag[:example_name]] =
                      { '$ref' => "#/components/examples/#{tag[:ref_name]}" }
                  end
                when :request_body_example_ref
                  if op['requestBody'] && op['requestBody']['content'] && op['requestBody']['content'][tag[:media_type]]
                    op['requestBody']['content'][tag[:media_type]]['examples'] ||= {}
                    op['requestBody']['content'][tag[:media_type]]['examples'][tag[:example_name]] =
                      { '$ref' => "#/components/examples/#{tag[:ref_name]}" }
                  end
                when :response_example_ref
                  if op['responses'][tag[:status]] && op['responses'][tag[:status]]['content'] && op['responses'][tag[:status]]['content'][tag[:media_type]]
                    op['responses'][tag[:status]]['content'][tag[:media_type]]['examples'] ||= {}
                    op['responses'][tag[:status]]['content'][tag[:media_type]]['examples'][tag[:example_name]] =
                      { '$ref' => "#/components/examples/#{tag[:ref_name]}" }
                  end
                when :request_body
                  rb = {
                    'content' => {
                      tag[:media_type] => {
                        'schema' => { '$ref' => "#/components/schemas/#{tag[:schema_name]}" }
                      }
                    }
                  }
                  tag[:options].each do |k, v|
                    rb[k] = if v == 'true'
                              true
                            elsif v == 'false'
                              false
                            else
                              v
                            end
                  end
                  rb['description'] = tag[:description] if tag[:description] && !tag[:description].empty?
                  op['requestBody'] = rb
                when :param_ref
                  params << { '$ref' => "#/components/parameters/#{tag[:name]}" }
                when :request_body_encoding
                  if op['requestBody'] && op['requestBody']['content'] && op['requestBody']['content'][tag[:media_type]]
                    op['requestBody']['content'][tag[:media_type]]['encoding'] ||= {}
                    enc = {}
                    tag[:options].each do |k, v|
                      enc[k] = (if v == 'true'
                                  true
                                else
                                  (v == 'false' ? false : v)
                                end)
                    end
                    enc['description'] = tag[:description] if tag[:description] && !tag[:description].empty?
                    op['requestBody']['content'][tag[:media_type]]['encoding'][tag[:property]] = enc
                  end
                when :response_ref
                  op['responses'][tag[:status]] = { '$ref' => "#/components/responses/#{tag[:name]}" }
                when :request_body_ref
                  op['requestBody'] = { '$ref' => "#/components/requestBodies/#{tag[:name]}" }
                when :response_header_ref
                  op['responses'][tag[:status]] ||= { 'description' => 'Response' }
                  op['responses'][tag[:status]]['headers'] ||= {}
                  op['responses'][tag[:status]]['headers'][tag[:name]] =
                    { '$ref' => "#/components/headers/#{tag[:ref_name]}" }
                when :link_ref
                  op['responses'][tag[:status]] ||= { 'description' => 'Response' }
                  op['responses'][tag[:status]]['links'] ||= {}
                  op['responses'][tag[:status]]['links'][tag[:name]] =
                    { '$ref' => "#/components/links/#{tag[:ref_name]}" }
                when :response_header

                  op['responses'][tag[:status]] ||= { 'description' => 'Response' }
                  op['responses'][tag[:status]]['headers'] ||= {}
                  h = {
                    'schema' => (if %w[string number integer boolean array
                                       object].include?(tag[:schema_type].downcase)
                                   { 'type' => tag[:schema_type].downcase }
                                 else
                                   { '$ref' => "#/components/schemas/#{tag[:schema_type]}" }
                                 end)
                  }
                  h['description'] = tag[:description] if tag[:description] && !tag[:description].empty?
                  tag[:options].each do |k, v|
                    h[k] = (if v == 'true'
                              true
                            else
                              (v == 'false' ? false : v)
                            end)
                  end
                  op['responses'][tag[:status]]['headers'][tag[:name]] = h
                when :link
                  op['responses'][tag[:status]] ||= { 'description' => 'Response' }
                  op['responses'][tag[:status]]['links'] ||= {}
                  l = {}
                  l['description'] = tag[:description] if tag[:description] && !tag[:description].empty?
                  tag[:options].each do |k, v|
                    if k.include?('.')
                      main_k, sub_k = k.split('.', 2)
                      l[main_k] ||= {}
                      l[main_k][sub_k] = v
                    else
                      l[k] = v
                    end
                  end
                  op['responses'][tag[:status]]['links'][tag[:name]] = l
                when :response

                  resp = {
                    'description' => tag[:description] && !tag[:description].empty? ? tag[:description].strip : 'Response'
                  }
                  if tag[:media_type] && tag[:schema_name]
                    resp['content'] = {
                      tag[:media_type] => {
                        'schema' => { '$ref' => "#/components/schemas/#{tag[:schema_name]}" }
                      }
                    }
                  end
                  tag[:options]&.each do |k, v|
                    if v == 'true'
                      v = true
                    elsif v == 'false'
                      v = false
                    end
                    if tag[:media_type]
                      resp['content'][tag[:media_type]][k] = v
                    else
                      resp[k] = v
                    end
                  end
                  op['responses'][tag[:status]] = resp
                when :security
                  security << if tag[:scheme]
                                { tag[:scheme] => tag[:scopes] }
                              else
                                {}
                              end
                when :callback
                  op['callbacks'] ||= {}
                  op['callbacks'][tag[:name]] ||= {}
                  op['callbacks'][tag[:name]][tag[:url]] ||= {}
                  op['callbacks'][tag[:name]][tag[:url]][tag[:method]] ||= { 'responses' => { '200' => { 'description' => 'OK' } } }
                when :callback_ref
                  op['callbacks'] ||= {}
                  op['callbacks'][tag[:name]] = { '$ref' => "#/components/callbacks/#{tag[:ref_name]}" }
                when :callback_request_body

                  if op['callbacks']
                    cb_name = op['callbacks'].keys.last
                    cb_url = op['callbacks'][cb_name].keys.last
                    cb_method = op['callbacks'][cb_name][cb_url].keys.last

                    rb = {
                      'content' => {
                        tag[:media_type] => {
                          'schema' => { '$ref' => "#/components/schemas/#{tag[:schema_name]}" }
                        }
                      }
                    }
                    if tag[:description] && !tag[:description].empty?
                      rb['description'] =
                        tag[:description]
                    end
                    op['callbacks'][cb_name][cb_url][cb_method]['requestBody'] = rb
                  end
                when :callback_response
                  if op['callbacks']
                    cb_name = op['callbacks'].keys.last
                    cb_url = op['callbacks'][cb_name].keys.last
                    cb_method = op['callbacks'][cb_name][cb_url].keys.last

                    resp = {
                      'description' => tag[:description] && !tag[:description].empty? ? tag[:description].strip : 'Response'
                    }
                    if tag[:media_type] && tag[:schema_name]
                      resp['content'] = {
                        tag[:media_type] => {
                          'schema' => { '$ref' => "#/components/schemas/#{tag[:schema_name]}" }
                        }
                      }
                    end
                    tag[:options]&.each do |k, v|
                      if v == 'true'
                        v = true
                      elsif v == 'false'
                        v = false
                      end
                      if tag[:media_type]
                        resp['content'][tag[:media_type]][k] = v
                      else
                        resp[k] = v
                      end
                    end
                    op['callbacks'][cb_name][cb_url][cb_method]['responses'][tag[:status]] = resp
                  end
                when :operationId
                  op['operationId'] = tag[:value]
                when :tag
                  tags << tag[:value]
                when :summary
                  op['summary'] = tag[:value]
                when :description
                  op['description'] = tag[:value]
                when :deprecated
                  op['deprecated'] = true
                when :external_docs
                  ed = { 'url' => tag[:url] }
                  ed['description'] = tag[:description] if tag[:description] && !tag[:description].empty?
                  op['externalDocs'] = ed
                when :op_server
                  srv = { 'url' => tag[:url] }
                  srv['description'] = tag[:description] if tag[:description] && !tag[:description].empty?
                  servers << srv
                when :path_summary
                  ir.openapi_spec['paths'][path]['summary'] = tag[:value]
                when :path_description
                  ir.openapi_spec['paths'][path]['description'] = tag[:value]
                end
              end

              # Auto-extract path parameters from the path string (e.g. /users/{id})
              path.scan(/\{(\w+)\}/).flatten.each do |path_param|
                next if params.any? { |p| p['name'] == path_param && p['in'] == 'path' }

                params << {
                  'name' => path_param,
                  'in' => 'path',
                  'required' => true,
                  'schema' => { 'type' => 'string' },
                  'description' => 'Auto-extracted path parameter'
                }
              end

              op['parameters'] = params unless params.empty?
              op['security'] = security unless security.empty?
              op['tags'] = tags unless tags.empty?
              op['servers'] = servers unless servers.empty?

              if is_webhook
                ir.openapi_spec['webhooks'][path][method] = op
              else
                ir.openapi_spec['paths'][path][method] = op
              end
              current_tags.clear

            end
          elsif %i[on_sp on_nl on_ignored_nl].include?(token[1])
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
