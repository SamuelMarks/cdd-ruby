# frozen_string_literal: true

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for parsing and emitting Sinatra route definitions.
  module Routes
    # Formatting and reusable component docstring emission helpers mixed into `Routes::Emitter`.
    module ComponentEmitter
      # Extracts the type or referenced schema name from a parameter or header object.
      #
      # @param holder [Hash] parameter or header hash containing a `'schema'` key
      # @return [String] resolved type or schema name
      def schema_type_name(holder)
        ref = holder.dig('schema', '$ref')
        ref ? ref.split('/').last : (holder.dig('schema', 'type') || 'string')
      end

      # Extracts the referenced schema name from a media type map's first entry.
      #
      # @param content_map [Hash] OpenAPI content map (`media_type => { 'schema' => ... }`)
      # @return [Array(String, String)] `[media_type, schema_name]`
      def first_media_schema(content_map)
        media_type = content_map.keys.first
        ref = content_map[media_type].dig('schema', '$ref')
        [media_type, ref ? ref.split('/').last : 'Object']
      end

      # Formats an array of `key:value` option strings with a leading space when non-empty.
      #
      # @param opts [Array<String>] option strings
      # @return [String] space-prefixed joined options or empty string
      def format_options_list(opts)
        opts.empty? ? '' : " #{opts.join(' ')}"
      end

      # Builds standard parameter option strings (`required`, `style`, `explode`, etc.).
      #
      # @param param [Hash] OpenAPI parameter object
      # @return [String] space-prefixed parameter option string
      def format_param_options(param)
        opts = []
        opts << "required:#{param['required']}" unless param['required'].nil?
        opts << "style:#{param['style']}" if param['style']
        opts << "explode:#{param['explode']}" unless param['explode'].nil?
        opts << "allowReserved:#{param['allowReserved']}" unless param['allowReserved'].nil?
        opts << "allowEmptyValue:#{param['allowEmptyValue']}" unless param['allowEmptyValue'].nil?
        opts << "deprecated:#{param['deprecated']}" unless param['deprecated'].nil?
        format_options_list(opts)
      end

      # Formats Link option strings (`operationId`, `operationRef`, `parameters.*`, `requestBody`).
      #
      # @param link_obj [Hash] OpenAPI Link object
      # @return [String] space-prefixed link options string
      def format_link_options(link_obj)
        l_opts = []
        l_opts << "operationId:#{link_obj['operationId']}" if link_obj['operationId']
        l_opts << "operationRef:#{link_obj['operationRef']}" if link_obj['operationRef']
        link_obj['parameters']&.each { |pk, pv| l_opts << "parameters.#{pk}:#{pv}" }
        l_opts << "requestBody:#{link_obj['requestBody']}" if link_obj['requestBody']
        format_options_list(l_opts)
      end

      # Emits all reusable `@component_*` docstring tags.
      #
      # @param components [Hash] OpenAPI `components` hash
      # @return [String] formatted component docstring tags
      def emit_components(components)
        out = emit_component_parameters(components['parameters'])
        out += emit_component_request_bodies(components['requestBodies'])
        out += emit_component_headers(components['headers'])
        out += emit_component_responses(components['responses'])
        out += emit_component_links(components['links'])
        out + emit_component_callbacks(components['callbacks'])
      end

      # Emits `@component_param` docstring tags.
      #
      # @param parameters [Hash, nil] `components.parameters` map
      # @return [String] formatted `@component_param` lines
      def emit_component_parameters(parameters)
        return '' unless parameters

        lines = parameters.map do |p_name, param|
          desc = param['description'] ? " #{param['description']}" : ''
          "# @component_param #{p_name} [#{schema_type_name(param)}] in:#{param['in']}" \
            "#{format_param_options(param)}#{desc}\n"
        end
        "#{lines.join}\n"
      end

      # Emits `@component_request_body` docstring tags.
      #
      # @param request_bodies [Hash, nil] `components.requestBodies` map
      # @return [String] formatted `@component_request_body` lines
      def emit_component_request_bodies(request_bodies)
        return '' unless request_bodies

        lines = request_bodies.map do |rb_name, rb|
          media_type, schema_name = first_media_schema(rb['content'])
          opts_str = rb['required'].nil? ? '' : " required:#{rb['required']}"
          desc = rb['description'] ? " description:#{rb['description']}" : ''
          "# @component_request_body #{rb_name} [#{schema_name}] #{media_type}#{opts_str}#{desc}\n"
        end
        "#{lines.join}\n"
      end

      # Emits `@component_header` docstring tags.
      #
      # @param headers [Hash, nil] `components.headers` map
      # @return [String] formatted `@component_header` lines
      def emit_component_headers(headers)
        return '' unless headers

        lines = headers.map do |h_name, hdr|
          opts_str = hdr['required'].nil? ? '' : " required:#{hdr['required']}"
          desc = hdr['description'] ? " description:#{hdr['description']}" : ''
          "# @component_header #{h_name} [#{schema_type_name(hdr)}]#{opts_str}#{desc}\n"
        end
        "#{lines.join}\n"
      end

      # Emits `@component_response` docstring tags.
      #
      # @param responses [Hash, nil] `components.responses` map
      # @return [String] formatted `@component_response` lines
      def emit_component_responses(responses)
        return '' unless responses

        lines = responses.map do |r_name, resp|
          desc = resp['description'] && resp['description'] != 'Response' ? " description:#{resp['description']}" : ''
          if resp['content']
            media_type, schema_name = first_media_schema(resp['content'])
            req_val = resp['content'][media_type]['required']
            opts_str = req_val.nil? ? '' : " required:#{req_val}"
            "# @component_response #{r_name} [#{schema_name}] #{media_type}#{opts_str}#{desc}\n"
          else
            "# @component_response #{r_name}#{desc}\n"
          end
        end
        "#{lines.join}\n"
      end

      # Emits `@component_link` docstring tags.
      #
      # @param links [Hash, nil] `components.links` map
      # @return [String] formatted `@component_link` lines
      def emit_component_links(links)
        return '' unless links

        lines = links.map do |l_name, link_obj|
          desc = link_obj['description'] ? " description:#{link_obj['description']}" : ''
          "# @component_link #{l_name}#{format_link_options(link_obj)}#{desc}\n"
        end
        "#{lines.join}\n"
      end

      # Emits `@component_callback*` docstring tags.
      #
      # @param callbacks [Hash, nil] `components.callbacks` map
      # @return [String] formatted `@component_callback*` lines
      def emit_component_callbacks(callbacks)
        return '' unless callbacks

        out = ''
        callbacks.each do |cb_name, cb_urls|
          cb_urls.each do |cb_url, cb_methods|
            cb_methods.each do |cb_method, cb_op|
              out += emit_single_callback_op('component_callback', cb_name, cb_url, cb_method, cb_op)
            end
          end
        end
        "#{out}\n"
      end

      # Emits a single callback operation and its request body / response tags.
      #
      # @param tag_prefix [String] `'component_callback'` or `'callback'`
      # @param cb_name [String] callback name
      # @param cb_url [String] callback URL expression
      # @param cb_method [String] HTTP method
      # @param cb_op [Hash] callback operation hash
      # @return [String] formatted callback docstring lines
      def emit_single_callback_op(tag_prefix, cb_name, cb_url, cb_method, cb_op)
        is_component = tag_prefix == 'component_callback'
        out = "# @#{tag_prefix} #{cb_name} #{cb_url} #{cb_method.downcase}\n"
        if cb_op['requestBody'] && cb_op['requestBody']['content']
          media_type, schema_name = first_media_schema(cb_op['requestBody']['content'])
          desc = cb_op['requestBody']['description'] ? " #{cb_op['requestBody']['description']}" : ''
          out += "# @#{tag_prefix}_request_body [#{schema_name}] #{media_type}#{desc}\n"
        end
        return out unless cb_op['responses']

        cb_op['responses'].each do |cb_status, cb_resp|
          next if cb_status == '200' && cb_resp['description'] == 'OK' && !cb_resp['content']

          out += format_callback_response_line(tag_prefix, cb_status, cb_resp, is_component)
        end
        out
      end

      # Formats a single `@callback_response` or `@component_callback_response` line.
      #
      # @param tag_prefix [String] `'component_callback'` or `'callback'`
      # @param cb_status [String] HTTP status code
      # @param cb_resp [Hash] callback response hash
      # @param is_component [Boolean] whether this is a component callback
      # @return [String] formatted callback response docstring line
      def format_callback_response_line(tag_prefix, cb_status, cb_resp, is_component)
        raw_desc = cb_resp['description']
        has_custom_desc = raw_desc && (!is_component || raw_desc != 'Response')
        if cb_resp['content']
          media_type, schema_name = first_media_schema(cb_resp['content'])
          desc = has_custom_desc ? " description:#{raw_desc}" : ''
          "# @#{tag_prefix}_response #{cb_status} [#{schema_name}] #{media_type}#{desc}\n"
        else
          desc = format_contentless_callback_desc(raw_desc, is_component)
          "# @#{tag_prefix}_response #{cb_status}#{desc}\n"
        end
      end

      # Formats the description suffix for a contentless callback response.
      #
      # @param raw_desc [String, nil] response description
      # @param is_component [Boolean] whether this is a component callback
      # @return [String] formatted description suffix
      def format_contentless_callback_desc(raw_desc, is_component)
        return '' unless raw_desc && raw_desc != 'Response'

        is_component ? " description:#{raw_desc}" : " #{raw_desc}"
      end
    end

    # Emitter for generating Sinatra route blocks and OpenAPI route docstrings from the IR.
    class Emitter
      extend ComponentEmitter

      # Emits server, security, component, route, and webhook blocks from the IR.
      #
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [String] generated Ruby route source code
      def self.emit(ir)
        out = emit_servers(ir.typed_servers, 'server')
        out += emit_global_security(ir.openapi_spec['security'] || [])
        out += emit_components(ir.openapi_spec['components'] || {})

        paths = ir.openapi_spec['paths'] || {}
        webhooks = ir.openapi_spec['webhooks'] || {}
        all_ops = paths.map { |p, data| { type: 'route', path: p, data: data } }
        webhooks.each { |w, data| all_ops << { type: 'webhook', path: w, data: data } }
        all_ops.each { |op_entry| out += emit_path_item(op_entry) }
        out
      end

      # Emits `@server` / `@server_var` or `@op_server` / `@op_server_var` docstring tags.
      #
      # @param servers [Array<Cdd::IR::Server, Hash>] list of OpenAPI server objects
      # @param prefix [String] `'server'` or `'op_server'`
      # @return [String] formatted server docstring lines
      def self.emit_servers(servers, prefix)
        out = ''
        servers.each do |srv|
          is_typed = srv.is_a?(Cdd::IR::Server)
          url = is_typed ? srv.url : srv['url']
          raw_desc = is_typed ? srv.description : srv['description']
          vars = is_typed ? srv.variables : (srv['variables'] || {})
          desc = if prefix == 'server'
                   " #{raw_desc}"
                 else
                   (raw_desc ? " #{raw_desc}" : '')
                 end
          out += "# @#{prefix} #{url}#{desc}\n"
          vars.each { |v_name, v_data| out += format_server_var_line(prefix, url, v_name, v_data) }
        end
        out
      end

      # Formats a single `@server_var` or `@op_server_var` docstring line.
      #
      # @param prefix [String] `'server'` or `'op_server'`
      # @param url [String] server URL
      # @param v_name [String] variable name
      # @param v_data [Cdd::IR::ServerVariable, Hash] server variable definition
      # @return [String] formatted server variable docstring line
      def self.format_server_var_line(prefix, url, v_name, v_data)
        is_typed = v_data.is_a?(Cdd::IR::ServerVariable)
        enum_list = is_typed ? v_data.enum : v_data['enum']
        var_desc = is_typed ? v_data.description : v_data['description']
        default_val = is_typed ? v_data.default : v_data['default']
        v_enum = enum_list ? " enum:#{enum_list.join(',')}" : ''
        v_desc = var_desc ? " description:#{var_desc}" : ''
        "# @#{prefix}_var #{url} #{v_name} #{default_val}#{v_enum}#{v_desc}\n"
      end

      # Emits top-level `@security` docstring tags.
      #
      # @param security_schemes [Array<Hash>] global security requirements array
      # @return [String] formatted `@security` lines
      def self.emit_global_security(security_schemes)
        out = ''
        security_schemes.each do |sec|
          sec.each { |scheme, scopes| out += "# @security #{scheme} #{scopes.join(', ')}\n" }
        end
        out
      end

      # Emits a single path item or webhook entry.
      #
      # @param op_entry [Hash] `{ type: 'route'|'webhook', path: String, data: Hash }`
      # @return [String] formatted route/webhook source code
      def self.emit_path_item(op_entry)
        path = op_entry[:path]
        path_data = op_entry[:data]
        return "# @route_ref #{path} #{path_data['$ref'].split('/').last}\n\n" if path_data['$ref']

        out = ''
        out += "# @path_summary #{path_data['summary']}\n" if path_data['summary']
        out += "# @path_description #{path_data['description']}\n" if path_data['description']
        path_data.each do |method, op|
          next if %w[summary description].include?(method)

          out += emit_operation(op_entry[:type], path, method, op)
        end
        out
      end

      # Emits a single HTTP operation's docstring tags and Sinatra route block.
      #
      # @param op_type [String] `'route'` or `'webhook'`
      # @param path [String] route path or webhook name
      # @param method [String] HTTP method
      # @param op [Hash] OpenAPI operation hash
      # @return [String] formatted operation docstrings and Sinatra block
      def self.emit_operation(op_type, path, method, op)
        out = emit_operation_metadata(op)
        out += emit_operation_parameters(op['parameters'] || [])
        out += emit_operation_request_body(op['requestBody'])
        out += emit_operation_responses(op['responses'] || {})
        out += emit_operation_callbacks(op['callbacks'] || {})
        out += emit_operation_security(op['security'])
        tag = op_type == 'webhook' ? 'webhook' : 'route'
        out += "# @#{tag} #{method.upcase} #{path}\n"
        "#{out}#{method.downcase} '#{path}' do\n  # TODO: implement\n  status 200\nend\n\n"
      end

      # Emits operation-level metadata tags (`@deprecated`, `@external_docs`, `@op_server`, `@operationId`, etc.).
      #
      # @param op [Hash] OpenAPI operation hash
      # @return [String] formatted operation metadata lines
      def self.emit_operation_metadata(op)
        out = ''
        out += "# @deprecated\n" if op['deprecated']
        if op['externalDocs']
          ed = op['externalDocs']
          desc = ed['description'] ? " #{ed['description']}" : ''
          out += "# @external_docs #{ed['url']}#{desc}\n"
        end
        out += emit_servers(op['servers'] || [], 'op_server')
        out += "# @operationId #{op['operationId']}\n" if op['operationId']
        out += "# @summary #{op['summary']}\n" if op['summary']
        out += "# @description #{op['description']}\n" if op['description']
        op['tags']&.each { |t| out += "# @tag #{t}\n" }
        out
      end

      # Emits operation-level `@param`, `@param_ref`, and `@param_example_ref` tags.
      #
      # @param parameters [Array<Hash>] operation parameters list
      # @return [String] formatted parameter docstring lines
      def self.emit_operation_parameters(parameters)
        out = ''
        parameters.each do |param|
          if param['$ref']
            out += "# @param_ref #{param['$ref'].split('/').last}\n"
            next
          end
          desc = if param['description'] && param['description'] != 'Auto-extracted path parameter'
                   " #{param['description']}"
                 else
                   ''
                 end
          out += "# @param #{param['name']} [#{schema_type_name(param)}] in:#{param['in']}" \
                 "#{format_param_options(param)}#{desc}\n"
          param['examples']&.each do |ex_name, ex|
            out += "# @param_example_ref #{param['name']} #{ex_name} #{ex['$ref'].split('/').last}\n" if ex['$ref']
          end
        end
        out
      end

      # Emits operation-level `@request_body*` tags.
      #
      # @param request_body [Hash, nil] operation `requestBody` hash
      # @return [String] formatted request body docstring lines
      def self.emit_operation_request_body(request_body)
        return '' unless request_body
        return "# @request_body_ref #{request_body['$ref'].split('/').last}\n" if request_body['$ref']

        media_type, schema_name = first_media_schema(request_body['content'])
        opts_str = request_body['required'].nil? ? '' : " required:#{request_body['required']}"
        desc = request_body['description'] ? " #{request_body['description']}" : ''
        out = "# @request_body [#{schema_name}] #{media_type}#{opts_str}#{desc}\n"
        request_body['content'].each do |m_type, content_data|
          content_data['examples']&.each do |ex_name, ex|
            out += "# @request_body_example_ref #{m_type} #{ex_name} #{ex['$ref'].split('/').last}\n" if ex['$ref']
          end
          out += emit_content_encodings(m_type, content_data['encoding']) if content_data['encoding']
        end
        out
      end

      # Emits `@request_body_encoding` docstring tags for a media type's `encoding` map.
      #
      # @param media_type [String] media type key
      # @param encodings [Hash] encoding map
      # @return [String] formatted `@request_body_encoding` lines
      def self.emit_content_encodings(media_type, encodings)
        out = ''
        encodings.each do |prop, enc|
          enc_opts = []
          enc_opts << "contentType:#{enc['contentType']}" if enc['contentType']
          enc_opts << "style:#{enc['style']}" if enc['style']
          enc_opts << "explode:#{enc['explode']}" unless enc['explode'].nil?
          enc_opts << "allowReserved:#{enc['allowReserved']}" unless enc['allowReserved'].nil?
          enc['headers']&.each { |hk, hv| enc_opts << "headers.#{hk}:$ref:#{hv['$ref']}" if hv['$ref'] }
          enc_desc = enc['description'] ? " description:#{enc['description']}" : ''
          out += "# @request_body_encoding #{media_type} #{prop}#{format_options_list(enc_opts)}#{enc_desc}\n"
        end
        out
      end

      # Emits operation-level `@response*`, `@response_header*`, and `@link*` tags.
      #
      # @param responses [Hash] operation `responses` map
      # @return [String] formatted response docstring lines
      def self.emit_operation_responses(responses)
        out = ''
        responses.each do |status, resp|
          if resp['$ref']
            out += "# @response_ref #{status} #{resp['$ref'].split('/').last}\n"
            next
          end
          next if default_ok_response?(status, resp)

          out += emit_single_response_body(status, resp)
          out += emit_response_headers(status, resp['headers'] || {})
          out += emit_response_links(status, resp['links'] || {})
        end
        out
      end

      # Checks if a response entry is the implicit default 200 OK with no extra metadata.
      #
      # @param status [String] HTTP status code
      # @param resp [Hash] OpenAPI response hash
      # @return [Boolean] true if default 200 OK
      def self.default_ok_response?(status, resp)
        status == '200' && resp['description'] == 'OK' && !resp['content'] && !resp['headers'] && !resp['links']
      end

      # Emits the `@response` and `@response_example_ref` lines for a single response status.
      #
      # @param status [String] HTTP status code
      # @param resp [Hash] OpenAPI response hash
      # @return [String] formatted `@response` lines
      def self.emit_single_response_body(status, resp)
        desc = resp['description'] && resp['description'] != 'Response' ? " #{resp['description']}" : ''
        if resp['content']
          media_type, schema_name = first_media_schema(resp['content'])
          req_val = resp['content'][media_type]['required']
          opts_str = req_val.nil? ? '' : " required:#{req_val}"
          out = "# @response #{status} [#{schema_name}] #{media_type}#{opts_str}#{desc}\n"
          resp['content'].each do |m_type, content_data|
            content_data['examples']&.each do |ex_name, ex|
              if ex['$ref']
                out += "# @response_example_ref #{status} #{m_type} #{ex_name} #{ex['$ref'].split('/').last}\n"
              end
            end
          end
          out
        else
          opts_str = resp['badRequest'].nil? ? '' : " badRequest:#{resp['badRequest']}"
          "# @response #{status}#{opts_str}#{desc}\n"
        end
      end

      # Emits `@response_header` and `@response_header_ref` docstring tags for a response status.
      #
      # @param status [String] HTTP status code
      # @param headers [Hash] response headers map
      # @return [String] formatted response header lines
      def self.emit_response_headers(status, headers)
        out = ''
        headers.each do |h_name, hdr|
          if hdr['$ref']
            out += "# @response_header_ref #{status} #{h_name} #{hdr['$ref'].split('/').last}\n"
          else
            opts_str = hdr['required'].nil? ? '' : " required:#{hdr['required']}"
            h_desc = hdr['description'] ? " #{hdr['description']}" : ''
            out += "# @response_header #{status} #{h_name} [#{schema_type_name(hdr)}]#{opts_str}#{h_desc}\n"
          end
        end
        out
      end

      # Emits `@link` and `@link_ref` docstring tags for a response status.
      #
      # @param status [String] HTTP status code
      # @param links [Hash] response links map
      # @return [String] formatted link lines
      def self.emit_response_links(status, links)
        out = ''
        links.each do |l_name, link_obj|
          if link_obj['$ref']
            out += "# @link_ref #{status} #{l_name} #{link_obj['$ref'].split('/').last}\n"
          else
            l_desc = link_obj['description'] ? " description:#{link_obj['description']}" : ''
            out += "# @link #{status} #{l_name}#{format_link_options(link_obj)}#{l_desc}\n"
          end
        end
        out
      end

      # Emits operation-level `@callback*` docstring tags.
      #
      # @param callbacks [Hash] operation `callbacks` map
      # @return [String] formatted callback docstring lines
      def self.emit_operation_callbacks(callbacks)
        out = ''
        callbacks.each do |cb_name, cb_urls|
          if cb_urls['$ref']
            out += "# @callback_ref #{cb_name} #{cb_urls['$ref'].split('/').last}\n"
            next
          end
          cb_urls.each do |cb_url, cb_methods|
            cb_methods.each do |cb_method, cb_op|
              out += emit_single_callback_op('callback', cb_name, cb_url, cb_method, cb_op)
            end
          end
        end
        out
      end

      # Emits operation-level `@security` docstring tags.
      #
      # @param security [Array<Hash>, nil] operation security requirements array
      # @return [String] formatted `@security` lines
      def self.emit_operation_security(security)
        return '' unless security && !security.empty?

        out = ''
        security.each do |sec|
          if sec.empty?
            out += "# @security \n"
          else
            sec.each do |scheme, scopes|
              scopes_str = scopes && !scopes.empty? ? " #{scopes.join(', ')}" : ''
              out += "# @security #{scheme}#{scopes_str}\n"
            end
          end
        end
        out
      end
    end
  end
end
