# frozen_string_literal: true

# Documentation for Cdd
module Cdd
  # Module for routes handling
  module Routes
    # Emitter for routes
    class Emitter
      # Emits routes from ir
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [String] generated output
      def self.emit(ir)
        out = ''
        servers = ir.openapi_spec['servers'] || []
        servers.each do |server|
          out += "# @server #{server['url']} #{server['description']}\n"
          next unless server['variables']

          server['variables'].each do |v_name, v_data|
            v_enum = v_data['enum'] ? " enum:#{v_data['enum'].join(',')}" : ''
            v_desc = v_data['description'] ? " description:#{v_data['description']}" : ''
            out += "# @server_var #{server['url']} #{v_name} #{v_data['default']}#{v_enum}#{v_desc}\n"
          end
        end

        security_schemes = ir.openapi_spec['security'] || []
        security_schemes.each do |sec|
          sec.each do |scheme, scopes|
            out += "# @security #{scheme} #{scopes.join(', ')}\n"
          end
        end

        components = ir.openapi_spec['components'] || {}
        if components['parameters']
          components['parameters'].each do |p_name, p|
            type = if p['schema'] && p['schema']['$ref']
                     p['schema']['$ref'].split('/').last
                   else
                     p.dig('schema', 'type') || 'string'
                   end
            opts = []
            opts << "required:#{p['required']}" unless p['required'].nil?
            opts << "style:#{p['style']}" if p['style']
            opts << "explode:#{p['explode']}" unless p['explode'].nil?
            opts << "allowReserved:#{p['allowReserved']}" unless p['allowReserved'].nil?
            opts << "allowEmptyValue:#{p['allowEmptyValue']}" unless p['allowEmptyValue'].nil?
            opts << "deprecated:#{p['deprecated']}" unless p['deprecated'].nil?
            opts_str = opts.empty? ? '' : " #{opts.join(' ')}"
            desc = p['description'] ? " #{p['description']}" : ''
            out += "# @component_param #{p_name} [#{type}] in:#{p['in']}#{opts_str}#{desc}\n"
          end
          out += "\n"
        end

        if components['requestBodies']
          components['requestBodies'].each do |rb_name, rb|
            media_type = rb['content'].keys.first
            ref = rb['content'][media_type].dig('schema', '$ref')
            schema_name = ref ? ref.split('/').last : 'Object'
            opts = []
            opts << "required:#{rb['required']}" unless rb['required'].nil?
            opts_str = opts.empty? ? '' : " #{opts.join(' ')}"
            desc = rb['description'] ? " description:#{rb['description']}" : ''
            out += "# @component_request_body #{rb_name} [#{schema_name}] #{media_type}#{opts_str}#{desc}\n"
          end
          out += "\n"
        end

        if components['headers']
          components['headers'].each do |h_name, h|
            type = if h['schema'] && h['schema']['$ref']
                     h['schema']['$ref'].split('/').last
                   else
                     h.dig('schema', 'type') || 'string'
                   end
            opts = []
            opts << "required:#{h['required']}" unless h['required'].nil?
            opts_str = opts.empty? ? '' : " #{opts.join(' ')}"
            desc = h['description'] ? " description:#{h['description']}" : ''
            out += "# @component_header #{h_name} [#{type}]#{opts_str}#{desc}\n"
          end
          out += "\n"
        end

        if components['responses']
          components['responses'].each do |r_name, resp|
            if resp['content']
              media_type = resp['content'].keys.first
              ref = resp['content'][media_type].dig('schema', '$ref')
              schema_name = ref ? ref.split('/').last : 'Object'
              opts = []
              unless resp['content'][media_type]['required'].nil?
                opts << "required:#{resp['content'][media_type]['required']}"
              end
              opts_str = opts.empty? ? '' : " #{opts.join(' ')}"
              desc = resp['description'] && resp['description'] != 'Response' ? " description:#{resp['description']}" : ''
              out += "# @component_response #{r_name} [#{schema_name}] #{media_type}#{opts_str}#{desc}\n"
            else
              opts = []
              opts_str = opts.empty? ? '' : " #{opts.join(' ')}"
              desc = resp['description'] && resp['description'] != 'Response' ? " description:#{resp['description']}" : ''
              out += "# @component_response #{r_name}#{opts_str}#{desc}\n"
            end
          end
          out += "\n"
        end

        if components['links']
          components['links'].each do |l_name, l|
            l_opts = []
            l_opts << "operationId:#{l['operationId']}" if l['operationId']
            l_opts << "operationRef:#{l['operationRef']}" if l['operationRef']
            l['parameters']&.each do |pk, pv|
              l_opts << "parameters.#{pk}:#{pv}"
            end
            l_opts << "requestBody:#{l['requestBody']}" if l['requestBody']
            l_opts_str = l_opts.empty? ? '' : " #{l_opts.join(' ')}"
            l_desc = l['description'] ? " description:#{l['description']}" : ''
            out += "# @component_link #{l_name}#{l_opts_str}#{l_desc}\n"
          end
          out += "\n"
        end

        if ir.openapi_spec['components'] && ir.openapi_spec['components']['callbacks']
          ir.openapi_spec['components']['callbacks'].each do |cb_name, cb_urls|
            cb_urls.each do |cb_url, cb_methods|
              cb_methods.each do |cb_method, cb_op|
                out += "# @component_callback #{cb_name} #{cb_url} #{cb_method.downcase}\n"

                if cb_op['requestBody'] && cb_op['requestBody']['content']
                  media_type = cb_op['requestBody']['content'].keys.first
                  ref = cb_op['requestBody']['content'][media_type].dig('schema', '$ref')
                  schema_name = ref ? ref.split('/').last : 'Object'
                  desc = cb_op['requestBody']['description'] ? " #{cb_op['requestBody']['description']}" : ''
                  out += "# @component_callback_request_body [#{schema_name}] #{media_type}#{desc}\n"
                end

                next unless cb_op['responses']

                cb_op['responses'].each do |cb_status, cb_resp|
                  next if cb_status == '200' && cb_resp['description'] == 'OK' && !cb_resp['content']

                  if cb_resp['content']
                    media_type = cb_resp['content'].keys.first
                    ref = cb_resp['content'][media_type].dig('schema', '$ref')
                    schema_name = ref ? ref.split('/').last : 'Object'
                    desc = cb_resp['description'] && cb_resp['description'] != 'Response' ? " description:#{cb_resp['description']}" : ''
                    out += "# @component_callback_response #{cb_status} [#{schema_name}] #{media_type}#{desc}\n"
                  else
                    desc = cb_resp['description'] && cb_resp['description'] != 'Response' ? " description:#{cb_resp['description']}" : ''
                    out += "# @component_callback_response #{cb_status}#{desc}\n"
                  end
                end
              end
            end
          end
          out += "\n"
        end

        paths = ir.openapi_spec['paths'] || {}
        webhooks = ir.openapi_spec['webhooks'] || {}

        all_ops = []
        paths.each { |p, data| all_ops << { type: 'route', path: p, data: data } }
        webhooks.each { |w, data| all_ops << { type: 'webhook', path: w, data: data } }

        all_ops.each do |op_entry|
          path = op_entry[:path]
          path_data = op_entry[:data]
          op_type = op_entry[:type]

          if path_data['$ref']
            ref_name = path_data['$ref'].split('/').last
            out += "# @route_ref #{path} #{ref_name}\n\n"
            next
          end

          out += "# @path_summary #{path_data['summary']}\n" if path_data['summary']
          out += "# @path_description #{path_data['description']}\n" if path_data['description']

          path_data.each do |method, op|
            next if %w[summary description].include?(method)

            out += "# @deprecated\n" if op['deprecated']

            if op['externalDocs']
              ed = op['externalDocs']
              desc = ed['description'] ? " #{ed['description']}" : ''
              out += "# @external_docs #{ed['url']}#{desc}\n"
            end

            op['servers']&.each do |srv|
              desc = srv['description'] ? " #{srv['description']}" : ''
              out += "# @op_server #{srv['url']}#{desc}\n"
              next unless srv['variables']

              srv['variables'].each do |v_name, v_data|
                v_enum = v_data['enum'] ? " enum:#{v_data['enum'].join(',')}" : ''
                v_desc = v_data['description'] ? " description:#{v_data['description']}" : ''
                out += "# @op_server_var #{srv['url']} #{v_name} #{v_data['default']}#{v_enum}#{v_desc}\n"
              end
            end

            out += "# @operationId #{op['operationId']}\n" if op['operationId']
            out += "# @summary #{op['summary']}\n" if op['summary']
            out += "# @description #{op['description']}\n" if op['description']
            op['tags']&.each do |t|
              out += "# @tag #{t}\n"
            end

            op['parameters']&.each do |p|
              if p['$ref']
                ref_name = p['$ref'].split('/').last
                out += "# @param_ref #{ref_name}\n"
                next
              end

              type = if p['schema'] && p['schema']['$ref']
                       p['schema']['$ref'].split('/').last
                     else
                       p.dig('schema', 'type') || 'string'
                     end

              opts = []
              opts << "required:#{p['required']}" unless p['required'].nil?
              opts << "style:#{p['style']}" if p['style']
              opts << "explode:#{p['explode']}" unless p['explode'].nil?
              opts << "allowReserved:#{p['allowReserved']}" unless p['allowReserved'].nil?
              opts << "allowEmptyValue:#{p['allowEmptyValue']}" unless p['allowEmptyValue'].nil?
              opts << "deprecated:#{p['deprecated']}" unless p['deprecated'].nil?

              opts_str = opts.empty? ? '' : " #{opts.join(' ')}"
              desc = p['description'] && p['description'] != 'Auto-extracted path parameter' ? " #{p['description']}" : ''

              out += "# @param #{p['name']} [#{type}] in:#{p['in']}#{opts_str}#{desc}\n"

              next unless p['examples']

              p['examples'].each do |ex_name, ex|
                if ex['$ref']
                  ref_name = ex['$ref'].split('/').last
                  out += "# @param_example_ref #{p['name']} #{ex_name} #{ref_name}\n"
                end
              end
            end

            if op['requestBody'] && op['requestBody']['$ref']
              ref_name = op['requestBody']['$ref'].split('/').last
              out += "# @request_body_ref #{ref_name}\n"
            elsif op['requestBody'] && op['requestBody']['content']
              media_type = op['requestBody']['content'].keys.first
              ref = op['requestBody']['content'][media_type].dig('schema', '$ref')
              schema_name = ref ? ref.split('/').last : 'Object'

              opts = []
              opts << "required:#{op['requestBody']['required']}" unless op['requestBody']['required'].nil?
              opts_str = opts.empty? ? '' : " #{opts.join(' ')}"
              desc = op['requestBody']['description'] ? " #{op['requestBody']['description']}" : ''

              out += "# @request_body [#{schema_name}] #{media_type}#{opts_str}#{desc}\n"

              op['requestBody']['content'].each do |m_type, content_data|
                content_data['examples']&.each do |ex_name, ex|
                  if ex['$ref']
                    ref_name = ex['$ref'].split('/').last
                    out += "# @request_body_example_ref #{m_type} #{ex_name} #{ref_name}\n"
                  end
                end

                next unless content_data['encoding']

                content_data['encoding'].each do |prop, enc|
                  enc_opts = []
                  enc_opts << "contentType:#{enc['contentType']}" if enc['contentType']
                  enc_opts << "style:#{enc['style']}" if enc['style']
                  enc_opts << "explode:#{enc['explode']}" unless enc['explode'].nil?
                  enc_opts << "allowReserved:#{enc['allowReserved']}" unless enc['allowReserved'].nil?
                  enc['headers']&.each do |hk, hv|
                    enc_opts << "headers.#{hk}:$ref:#{hv['$ref']}" if hv['$ref']
                  end
                  enc_opts_str = enc_opts.empty? ? '' : " #{enc_opts.join(' ')}"
                  enc_desc = enc['description'] ? " description:#{enc['description']}" : ''
                  out += "# @request_body_encoding #{m_type} #{prop}#{enc_opts_str}#{enc_desc}\n"
                end
              end
            end

            op['responses']&.each do |status, resp|
              if resp['$ref']
                ref_name = resp['$ref'].split('/').last
                out += "# @response_ref #{status} #{ref_name}\n"
                next
              end

              if status == '200' && resp['description'] == 'OK' && !resp['content'] && !resp['headers'] && !resp['links'] && !resp['$ref']
                next
              end

              if resp['content']
                media_type = resp['content'].keys.first
                ref = resp['content'][media_type].dig('schema', '$ref')
                schema_name = ref ? ref.split('/').last : 'Object'

                opts = []
                unless resp['content'][media_type]['required'].nil?
                  opts << "required:#{resp['content'][media_type]['required']}"
                end
                opts_str = opts.empty? ? '' : " #{opts.join(' ')}"

                desc = resp['description'] && resp['description'] != 'Response' ? " #{resp['description']}" : ''
                out += "# @response #{status} [#{schema_name}] #{media_type}#{opts_str}#{desc}\n"

                resp['content'].each do |m_type, content_data|
                  next unless content_data['examples']

                  content_data['examples'].each do |ex_name, ex|
                    if ex['$ref']
                      ref_name = ex['$ref'].split('/').last
                      out += "# @response_example_ref #{status} #{m_type} #{ex_name} #{ref_name}\n"
                    end
                  end
                end
              else
                opts = []
                opts << "badRequest:#{resp['badRequest']}" unless resp['badRequest'].nil?
                opts_str = opts.empty? ? '' : " #{opts.join(' ')}"
                desc = resp['description'] && resp['description'] != 'Response' ? " #{resp['description']}" : ''
                out += "# @response #{status}#{opts_str}#{desc}\n"
              end

              resp['headers']&.each do |h_name, h|
                if h['$ref']
                  ref_name = h['$ref'].split('/').last
                  out += "# @response_header_ref #{status} #{h_name} #{ref_name}\n"
                else
                  h_type = if h['schema'] && h['schema']['$ref']
                             h['schema']['$ref'].split('/').last
                           else
                             h.dig('schema', 'type') || 'string'
                           end
                  h_opts = []
                  h_opts << "required:#{h['required']}" unless h['required'].nil?
                  h_opts_str = h_opts.empty? ? '' : " #{h_opts.join(' ')}"
                  h_desc = h['description'] ? " #{h['description']}" : ''
                  out += "# @response_header #{status} #{h_name} [#{h_type}]#{h_opts_str}#{h_desc}\n"
                end
              end

              next unless resp['links']

              resp['links'].each do |l_name, l|
                if l['$ref']
                  ref_name = l['$ref'].split('/').last
                  out += "# @link_ref #{status} #{l_name} #{ref_name}\n"
                else
                  l_opts = []
                  l_opts << "operationId:#{l['operationId']}" if l['operationId']
                  l_opts << "operationRef:#{l['operationRef']}" if l['operationRef']
                  l['parameters']&.each do |pk, pv|
                    l_opts << "parameters.#{pk}:#{pv}"
                  end
                  l_opts << "requestBody:#{l['requestBody']}" if l['requestBody']
                  l_opts_str = l_opts.empty? ? '' : " #{l_opts.join(' ')}"
                  l_desc = l['description'] ? " description:#{l['description']}" : ''
                  out += "# @link #{status} #{l_name}#{l_opts_str}#{l_desc}\n"
                end
              end
            end

            op['callbacks']&.each do |cb_name, cb_urls|
              if cb_urls['$ref']
                ref_name = cb_urls['$ref'].split('/').last
                out += "# @callback_ref #{cb_name} #{ref_name}\n"
                next
              end
              cb_urls.each do |cb_url, cb_methods|
                cb_methods.each do |cb_method, cb_op|
                  out += "# @callback #{cb_name} #{cb_url} #{cb_method.downcase}\n"

                  if cb_op['requestBody'] && cb_op['requestBody']['content']
                    media_type = cb_op['requestBody']['content'].keys.first
                    ref = cb_op['requestBody']['content'][media_type].dig('schema', '$ref')
                    schema_name = ref ? ref.split('/').last : 'Object'
                    desc = cb_op['requestBody']['description'] ? " #{cb_op['requestBody']['description']}" : ''
                    out += "# @callback_request_body [#{schema_name}] #{media_type}#{desc}\n"
                  end

                  next unless cb_op['responses']

                  cb_op['responses'].each do |cb_status, cb_resp|
                    next if cb_status == '200' && cb_resp['description'] == 'OK' && !cb_resp['content']

                    if cb_resp['content']
                      media_type = cb_resp['content'].keys.first
                      ref = cb_resp['content'][media_type].dig('schema', '$ref')
                      schema_name = ref ? ref.split('/').last : 'Object'
                      desc = cb_resp['description'] ? " description:#{cb_resp['description']}" : ''
                      out += "# @callback_response #{cb_status} [#{schema_name}] #{media_type}#{desc}\n"
                    else
                      desc = cb_resp['description'] && cb_resp['description'] != 'Response' ? " #{cb_resp['description']}" : ''
                      out += "# @callback_response #{cb_status}#{desc}\n"
                    end
                  end
                end
              end
            end

            if op['security'] && !op['security'].empty?
              op['security'].each do |sec|
                if sec.empty?
                  out += "# @security \n"
                else
                  sec.each do |scheme, scopes|
                    scopes_str = scopes && !scopes.empty? ? " #{scopes.join(', ')}" : ''
                    out += "# @security #{scheme}#{scopes_str}\n"
                  end
                end
              end
            end

            out += if op_type == 'webhook'
                     "# @webhook #{method.upcase} #{path}\n"
                   else
                     "# @route #{method.upcase} #{path}\n"
                   end
            out += "#{method.downcase} '#{path}' do\n"
            out += "  # TODO: implement\n"
            out += "  status 200\n"
            out += "end\n\n"
          end
        end
        out
      end
    end
  end
end
