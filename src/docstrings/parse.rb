# frozen_string_literal: true

require_relative '../token_scanner'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for parsing and emitting OpenAPI docstring annotations.
  module Docstrings
    # Shared docstring option and schema reference helpers.
    module TagHelpers
      # Primitive JSON Schema types recognized inline without `$ref` wrapping.
      PRIMITIVE_TYPES = %w[string number integer boolean array object].freeze

      # Extracts key-value pairs and remaining description text from a docstring suffix.
      #
      # @param rest [String, nil] trailing docstring text
      # @return [Array(Hash{String => String}, String)] extracted key-value pairs and remaining description
      def parse_rest(rest)
        return [{}, ''] if rest.nil? || rest.strip.empty?

        pairs = {}
        new_rest = []
        rest.split.each do |part|
          if part.start_with?('description:')
            new_rest << part.sub(/^description:/, '')
          elsif part =~ /\A[a-zA-Z0-9_.-]+:\S+\z/
            k, v = part.split(':', 2)
            pairs[k] = v
          else
            new_rest << part
          end
        end
        [pairs, new_rest.join(' ')]
      end

      # Coerces `'true'` and `'false'` strings into booleans while preserving other values.
      #
      # @param val [String, Object] raw option value
      # @return [Boolean, String, Object] coerced value
      def coerce_boolean_or_string(val)
        return true if val == 'true'
        return false if val == 'false'

        val
      end

      # Builds a JSON Schema hash (`type` for primitives, `$ref` for component references).
      #
      # @param schema_type [String] primitive type name or component schema name
      # @return [Hash{String => String}] OpenAPI schema object
      def schema_or_ref(schema_type)
        down = schema_type.downcase
        PRIMITIVE_TYPES.include?(down) ? { 'type' => down } : { '$ref' => "#/components/schemas/#{schema_type}" }
      end

      # Applies coerced key-value pairs onto a target hash.
      #
      # @param target [Hash] destination hash
      # @param pairs [Hash] raw string key-value pairs
      # @return [void]
      def apply_coerced_pairs(target, pairs)
        (pairs || {}).each { |k, v| target[k] = coerce_boolean_or_string(v) }
      end

      # Applies dotted or flat key-value pairs onto a Link hash.
      #
      # @param link_obj [Hash] target OpenAPI Link hash
      # @param pairs [Hash] key-value pairs
      # @return [void]
      def apply_link_pairs(link_obj, pairs)
        pairs.each do |k, v|
          if k.include?('.')
            main_k, sub_k = k.split('.', 2)
            link_obj[main_k] ||= {}
            link_obj[main_k][sub_k] = v
          else
            link_obj[k] = v
          end
        end
      end

      # Builds an OpenAPI Response object from schema, media_type, options, and description.
      #
      # @param schema_name [String, nil] schema reference name
      # @param media_type [String, nil] content media type
      # @param pairs [Hash] option key-value pairs
      # @param desc_text [String, nil] response description
      # @return [Hash] OpenAPI Response hash
      def build_response_object(schema_name, media_type, pairs, desc_text)
        clean_desc = desc_text.to_s.strip
        resp = { 'description' => clean_desc.empty? ? 'Response' : clean_desc }
        if media_type && schema_name
          resp['content'] = { media_type => { 'schema' => { '$ref' => "#/components/schemas/#{schema_name}" } } }
          apply_coerced_pairs(resp['content'][media_type], pairs)
        else
          apply_coerced_pairs(resp, pairs)
        end
        resp
      end

      # Finds the last operation hash inside a callbacks map.
      #
      # @param callbacks [Hash, nil] callbacks map
      # @return [Hash, nil] the last callback operation hash or nil
      def last_callback_operation(callbacks)
        return nil unless callbacks

        cb_name = callbacks.keys.last
        cb_url = callbacks[cb_name].keys.last
        cb_method = callbacks[cb_name][cb_url].keys.last
        callbacks[cb_name][cb_url][cb_method]
      end
    end

    # Attaches reusable `@component_*`, `@security_scheme`, and `@schema*` tags onto the IR.
    module ComponentAttacher
      include TagHelpers

      # Parses `@security_scheme`, `@schema_xml`, `@schema_one_of`, `@schema_any_of`, and `@schema` tags.
      #
      # @param comment [String] raw comment line
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [Boolean] true if matched
      def parse_schema_tags?(comment, ir)
        case comment
        when /#\s*@security_scheme\s+(\w+)\s+(\w+)(?:\s+(.*))?/
          parse_security_scheme_tag(::Regexp.last_match(1), ::Regexp.last_match(2), ::Regexp.last_match(3) || '', ir)
        when /#\s*@schema_xml\s+(\w+)(?:\s+(.*))?/
          parse_schema_xml_tag(::Regexp.last_match(1), ::Regexp.last_match(2) || '', ir)
        when /#\s*@(schema_one_of|schema_any_of)\s+(\w+)\s+(.*)/
          comp_key = ::Regexp.last_match(1) == 'schema_one_of' ? 'oneOf' : 'anyOf'
          parse_composition_tag(comp_key, ::Regexp.last_match(2), ::Regexp.last_match(3), ir)
        when /#\s*@schema\s+(\w+)(?:\s+(.*))?/
          parse_object_schema_tag(::Regexp.last_match(1), ::Regexp.last_match(2) || '', ir)
        else
          return false
        end
        true
      end

      # Parses a `@security_scheme` tag into `components.securitySchemes`.
      #
      # @param scheme_name [String] security scheme key
      # @param type [String] security scheme type
      # @param rest [String] options and description
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def parse_security_scheme_tag(scheme_name, type, rest, ir)
        pairs, parsed_rest = parse_rest(rest)
        ir.openapi_spec['components'] ||= {}
        ir.openapi_spec['components']['securitySchemes'] ||= {}
        scheme = { 'type' => type }.merge(pairs)
        scheme['description'] = parsed_rest.strip unless parsed_rest.strip.empty?
        ir.openapi_spec['components']['securitySchemes'][scheme_name] = scheme
      end

      # Parses a `@schema_xml` tag into a schema's `xml` metadata object.
      #
      # @param schema_name [String] target schema name
      # @param rest [String] key:value XML options
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def parse_schema_xml_tag(schema_name, rest, ir)
        pairs = {}
        while rest =~ /^([a-zA-Z]+):(\S+)\s+(.*)$/
          pairs[::Regexp.last_match(1)] = ::Regexp.last_match(2)
          rest = ::Regexp.last_match(3)
        end
        pairs[::Regexp.last_match(1)] = ::Regexp.last_match(2) if rest =~ /^([a-zA-Z]+):(\S+)$/

        ir.openapi_spec['components'] ||= {}
        ir.openapi_spec['components']['schemas'] ||= {}
        ir.openapi_spec['components']['schemas'][schema_name] ||= { 'type' => 'object' }
        xml_hash = (ir.openapi_spec['components']['schemas'][schema_name]['xml'] ||= {})
        apply_coerced_pairs(xml_hash, pairs)
      end

      # Parses `@schema_one_of` and `@schema_any_of` tags into `components.schemas`.
      #
      # @param comp_key [String] `'oneOf'` or `'anyOf'`
      # @param schema_name [String] schema name
      # @param rest [String] comma-separated refs and optional discriminator options
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def parse_composition_tag(comp_key, schema_name, rest, ir)
        ir.openapi_spec['components'] ||= {}
        ir.openapi_spec['components']['schemas'] ||= {}
        if rest =~ /^([a-zA-Z0-9_,\s]+)\s+discriminator:(\w+)(?:\s+mapping:([^\s]+))?(?:\s+defaultMapping:(\w+))?$/
          m = ::Regexp.last_match
          refs = m[1].split(/\s*,\s*/).map { |r| { '$ref' => "#/components/schemas/#{r}" } }
          disc = { 'propertyName' => m[2] }
          if m[3]
            disc['mapping'] = m[3].split(/\s*,\s*/).to_h do |pair|
              k, v = pair.split(':')
              [k, "#/components/schemas/#{v}"]
            end
          end
          disc['defaultMapping'] = "#/components/schemas/#{m[4]}" if m[4]
          ir.openapi_spec['components']['schemas'][schema_name] = { comp_key => refs, 'discriminator' => disc }
        else
          refs = rest.split(/\s*,\s*/).map { |r| { '$ref' => "#/components/schemas/#{r}" } }
          ir.openapi_spec['components']['schemas'][schema_name] ||= { comp_key => refs }
        end
      end

      # Parses a `@schema` tag into `components.schemas`.
      #
      # @param schema_name [String] schema name
      # @param rest [String] options and description
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def parse_object_schema_tag(schema_name, rest, ir)
        pairs, parsed_rest = parse_rest(rest)
        ir.openapi_spec['components'] ||= {}
        ir.openapi_spec['components']['schemas'] ||= {}
        schema = (ir.openapi_spec['components']['schemas'][schema_name] ||= { 'type' => 'object', 'properties' => {} })
        pairs.each { |k, v| schema[k] = v }
        schema['description'] = parsed_rest.strip unless parsed_rest.strip.empty?
      end

      # Parses reusable `@component_*` tags into `ir.openapi_spec['components']`.
      #
      # @param comment [String] raw comment line
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [Boolean] true if matched
      def parse_component_tags?(comment, ir)
        case comment
        when /#\s*@component_param\s+(\w+)\s+\[(\w+)\]\s+in:(\w+)(?:\s+(.*))?/
          parse_component_param(::Regexp.last_match(1), ::Regexp.last_match(2),
                                ::Regexp.last_match(3), ::Regexp.last_match(4) || '', ir)
        when /#\s*@component_request_body\s+(\w+)\s+\[(\w+)\]\s+(\S+)(?:\s+(.*))?/
          parse_component_request_body(::Regexp.last_match(1), ::Regexp.last_match(2),
                                       ::Regexp.last_match(3), ::Regexp.last_match(4) || '', ir)
        when /#\s*@component_header\s+(\w+)\s+\[(\w+)\](?:\s+(.*))?/
          parse_component_header(::Regexp.last_match(1), ::Regexp.last_match(2), ::Regexp.last_match(3) || '', ir)
        when /#\s*@component_link\s+(\w+)(?:\s+(.*))?/
          parse_component_link(::Regexp.last_match(1), ::Regexp.last_match(2) || '', ir)
        when /#\s*@component_response\s+(\w+)(?:\s+\[(\w+)\]\s+(\S+))?(?:\s+(.*))?/
          parse_component_response(::Regexp.last_match(1), ::Regexp.last_match(2),
                                   ::Regexp.last_match(3), ::Regexp.last_match(4) || '', ir)
        else
          return parse_component_callback_tags?(comment, ir)
        end
        true
      end

      # Parses `@component_param` into `components.parameters`.
      #
      # @param name [String] parameter component key
      # @param schema_type [String] type or schema reference
      # @param loc [String] parameter location (`query`, `header`, `path`, `cookie`)
      # @param rest [String] trailing options and description
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def parse_component_param(name, schema_type, loc, rest, ir)
        pairs, parsed_rest = parse_rest(rest)
        param = { 'name' => name, 'in' => loc, 'schema' => schema_or_ref(schema_type) }
        apply_coerced_pairs(param, pairs)
        param['description'] = parsed_rest.strip unless parsed_rest.strip.empty?
        ir.openapi_spec['components'] ||= {}
        (ir.openapi_spec['components']['parameters'] ||= {})[name] = param
      end

      # Parses `@component_request_body` into `components.requestBodies`.
      #
      # @param name [String] requestBody component key
      # @param schema_name [String] referenced schema name
      # @param media_type [String] media type string
      # @param rest [String] trailing options and description
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def parse_component_request_body(name, schema_name, media_type, rest, ir)
        pairs, parsed_rest = parse_rest(rest)
        rb = { 'content' => { media_type => { 'schema' => { '$ref' => "#/components/schemas/#{schema_name}" } } } }
        apply_coerced_pairs(rb, pairs)
        rb['description'] = parsed_rest.strip unless parsed_rest.empty?
        ir.openapi_spec['components'] ||= {}
        (ir.openapi_spec['components']['requestBodies'] ||= {})[name] = rb
      end

      # Parses `@component_header` into `components.headers`.
      #
      # @param name [String] header component key
      # @param schema_type [String] type or schema reference
      # @param rest [String] trailing options and description
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def parse_component_header(name, schema_type, rest, ir)
        pairs, parsed_rest = parse_rest(rest)
        hdr = { 'schema' => schema_or_ref(schema_type) }
        apply_coerced_pairs(hdr, pairs)
        hdr['description'] = parsed_rest.strip unless parsed_rest.empty?
        ir.openapi_spec['components'] ||= {}
        (ir.openapi_spec['components']['headers'] ||= {})[name] = hdr
      end

      # Parses `@component_link` into `components.links`.
      #
      # @param name [String] link component key
      # @param rest [String] trailing options and description
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def parse_component_link(name, rest, ir)
        pairs, parsed_rest = parse_rest(rest)
        link_obj = {}
        apply_link_pairs(link_obj, pairs)
        link_obj['description'] = parsed_rest.strip unless parsed_rest.empty?
        ir.openapi_spec['components'] ||= {}
        (ir.openapi_spec['components']['links'] ||= {})[name] = link_obj
      end

      # Parses `@component_response` into `components.responses`.
      #
      # @param name [String] response component key
      # @param schema_name [String, nil] optional schema name
      # @param media_type [String, nil] optional media type
      # @param rest [String] trailing options and description
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def parse_component_response(name, schema_name, media_type, rest, ir)
        pairs, parsed_rest = parse_rest(rest)
        resp = build_response_object(schema_name, media_type, pairs, parsed_rest)
        ir.openapi_spec['components'] ||= {}
        (ir.openapi_spec['components']['responses'] ||= {})[name] = resp
      end

      # Parses `@component_callback*` tags into `components.callbacks`.
      #
      # @param comment [String] raw comment line
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [Boolean] true if matched
      def parse_component_callback_tags?(comment, ir)
        case comment
        when /#\s*@component_callback\s+(\w+)\s+(\S+)\s+(get|put|post|delete|options|head|patch|trace|query)/i
          name = ::Regexp.last_match(1)
          url = ::Regexp.last_match(2)
          method = ::Regexp.last_match(3).downcase
          ir.openapi_spec['components'] ||= {}
          cbs = (ir.openapi_spec['components']['callbacks'] ||= {})
          ((cbs[name] ||= {})[url] ||= {})[method] ||= { 'responses' => { '200' => { 'description' => 'OK' } } }
        when /#\s*@component_callback_request_body\s+\[(\w+)\]\s+(\S+)(?:\s+(.*))?/
          attach_component_callback_request_body(::Regexp.last_match(1), ::Regexp.last_match(2),
                                                 (::Regexp.last_match(3) || '').strip, ir)
        when /#\s*@component_callback_response\s+(\d+|default)(?:\s+\[(\w+)\]\s+(\S+))?(?:\s+(.*))?/
          attach_component_callback_response(::Regexp.last_match(1), ::Regexp.last_match(2),
                                             ::Regexp.last_match(3), ::Regexp.last_match(4) || '', ir)
        else
          return false
        end
        true
      end

      # Attaches a request body to the most recently declared component callback operation.
      #
      # @param schema_name [String] schema name
      # @param media_type [String] media type
      # @param rest [String] description text
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def attach_component_callback_request_body(schema_name, media_type, rest, ir)
        cb_op = last_callback_operation(ir.openapi_spec.dig('components', 'callbacks'))
        return unless cb_op

        rb = { 'content' => { media_type => { 'schema' => { '$ref' => "#/components/schemas/#{schema_name}" } } } }
        rb['description'] = rest unless rest.empty?
        cb_op['requestBody'] = rb
      end

      # Attaches a response to the most recently declared component callback operation.
      #
      # @param status [String] HTTP status code
      # @param schema_name [String, nil] schema name
      # @param media_type [String, nil] media type
      # @param rest [String] options and description
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def attach_component_callback_response(status, schema_name, media_type, rest, ir)
        cb_op = last_callback_operation(ir.openapi_spec.dig('components', 'callbacks'))
        return unless cb_op

        pairs, parsed_rest = parse_rest(rest)
        cb_op['responses'][status] = build_response_object(schema_name, media_type, pairs, parsed_rest)
      end
    end

    # Attaches operation-level docstring tags onto OpenAPI operations and paths.
    module OperationAttacher
      include TagHelpers

      # Assembles an OpenAPI operation hash from accumulated tags when `@route` or `@webhook` is encountered.
      #
      # @param is_webhook [Boolean] true if `@webhook`, false if `@route`
      # @param method [String] lowercase HTTP method
      # @param path [String] route path or webhook name
      # @param current_tags [Array<Hash>] accumulated operation tags
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def build_operation_from_tags(is_webhook, method, path, current_tags, ir)
        root_key = is_webhook ? 'webhooks' : 'paths'
        ir.routes |= ["#{method.upcase} #{path}"] unless is_webhook
        ir.openapi_spec[root_key] ||= {}
        ir.openapi_spec[root_key][path] ||= {}

        ctx = {
          op: { 'responses' => { '200' => { 'description' => 'OK' } } },
          params: [],
          security: [],
          tags: [],
          servers: [],
          path: path,
          ir: ir
        }

        current_tags.each { |tag| apply_operation_tag(tag, ctx) }
        extract_implicit_path_params(path, ctx[:params])

        ctx[:op]['parameters'] = ctx[:params] unless ctx[:params].empty?
        ctx[:op]['security'] = ctx[:security] unless ctx[:security].empty?
        ctx[:op]['tags'] = ctx[:tags] unless ctx[:tags].empty?
        ctx[:op]['servers'] = ctx[:servers] unless ctx[:servers].empty?

        ir.openapi_spec[root_key][path][method] = ctx[:op]
        current_tags.clear
      end

      # Applies a single accumulated tag hash onto the operation builder context.
      #
      # @param tag [Hash] parsed tag entry
      # @param ctx [Hash] operation builder context
      # @return [void]
      def apply_operation_tag(tag, ctx)
        case tag[:type]
        when :param, :param_ref, :param_example_ref
          apply_param_tag(tag, ctx[:params])
        when :request_body, :request_body_ref, :request_body_example_ref, :request_body_encoding
          apply_request_body_tag(tag, ctx[:op])
        when :response, :response_ref, :response_example_ref
          apply_response_body_tag(tag, ctx[:op])
        when :response_header, :response_header_ref, :link, :link_ref
          apply_header_or_link_tag(tag, ctx[:op])
        when :callback, :callback_ref, :callback_request_body, :callback_response
          apply_callback_tag(tag, ctx[:op])
        else
          apply_meta_or_server_tag(tag, ctx)
        end
      end

      # Applies `@param`, `@param_ref`, and `@param_example_ref` tags onto `params`.
      #
      # @param tag [Hash] parsed tag entry
      # @param params [Array<Hash>] operation parameters list
      # @return [void]
      def apply_param_tag(tag, params)
        case tag[:type]
        when :param
          p = { 'name' => tag[:name], 'in' => tag[:in], 'schema' => schema_or_ref(tag[:schema_type]) }
          apply_coerced_pairs(p, tag[:options])
          p['description'] = tag[:description] if tag[:description] && !tag[:description].empty?
          params << p
        when :param_ref
          params << { '$ref' => "#/components/parameters/#{tag[:name]}" }
        else
          target = params.find { |param| param['name'] == tag[:param_name] }
          return unless target

          (target['examples'] ||= {})[tag[:example_name]] = { '$ref' => "#/components/examples/#{tag[:ref_name]}" }
        end
      end

      # Applies `@request_body*` tags onto `op`.
      #
      # @param tag [Hash] parsed tag entry
      # @param op [Hash] OpenAPI operation hash
      # @return [void]
      def apply_request_body_tag(tag, op)
        case tag[:type]
        when :request_body
          ref_schema = { '$ref' => "#/components/schemas/#{tag[:schema_name]}" }
          rb = { 'content' => { tag[:media_type] => { 'schema' => ref_schema } } }
          apply_coerced_pairs(rb, tag[:options])
          rb['description'] = tag[:description] if tag[:description] && !tag[:description].empty?
          op['requestBody'] = rb
        when :request_body_ref
          op['requestBody'] = { '$ref' => "#/components/requestBodies/#{tag[:name]}" }
        when :request_body_example_ref
          media = op.dig('requestBody', 'content', tag[:media_type])
          return unless media

          (media['examples'] ||= {})[tag[:example_name]] = { '$ref' => "#/components/examples/#{tag[:ref_name]}" }
        else
          media = op.dig('requestBody', 'content', tag[:media_type])
          return unless media

          enc = {}
          apply_coerced_pairs(enc, tag[:options])
          enc['description'] = tag[:description] if tag[:description] && !tag[:description].empty?
          (media['encoding'] ||= {})[tag[:property]] = enc
        end
      end

      # Applies `@response`, `@response_ref`, and `@response_example_ref` tags onto `op`.
      #
      # @param tag [Hash] parsed tag entry
      # @param op [Hash] OpenAPI operation hash
      # @return [void]
      def apply_response_body_tag(tag, op)
        case tag[:type]
        when :response
          op['responses'][tag[:status]] = build_response_object(tag[:schema_name], tag[:media_type],
                                                                tag[:options], tag[:description])
        when :response_ref
          op['responses'][tag[:status]] = { '$ref' => "#/components/responses/#{tag[:name]}" }
        else
          media = op.dig('responses', tag[:status], 'content', tag[:media_type])
          return unless media

          (media['examples'] ||= {})[tag[:example_name]] = { '$ref' => "#/components/examples/#{tag[:ref_name]}" }
        end
      end

      # Applies `@response_header*` and `@link*` tags onto `op`.
      #
      # @param tag [Hash] parsed tag entry
      # @param op [Hash] OpenAPI operation hash
      # @return [void]
      def apply_header_or_link_tag(tag, op)
        resp = (op['responses'][tag[:status]] ||= { 'description' => 'Response' })
        if %i[response_header response_header_ref].include?(tag[:type])
          attach_response_header_tag(tag, resp)
        else
          attach_response_link_tag(tag, resp)
        end
      end

      # Attaches a `@response_header` or `@response_header_ref` tag onto a response object.
      #
      # @param tag [Hash] parsed header tag
      # @param resp [Hash] OpenAPI response hash
      # @return [void]
      def attach_response_header_tag(tag, resp)
        headers = (resp['headers'] ||= {})
        if tag[:type] == :response_header_ref
          headers[tag[:name]] = { '$ref' => "#/components/headers/#{tag[:ref_name]}" }
          return
        end
        hdr = { 'schema' => schema_or_ref(tag[:schema_type]) }
        hdr['description'] = tag[:description] if tag[:description] && !tag[:description].empty?
        apply_coerced_pairs(hdr, tag[:options])
        headers[tag[:name]] = hdr
      end

      # Attaches a `@link` or `@link_ref` tag onto a response object.
      #
      # @param tag [Hash] parsed link tag
      # @param resp [Hash] OpenAPI response hash
      # @return [void]
      def attach_response_link_tag(tag, resp)
        links = (resp['links'] ||= {})
        if tag[:type] == :link_ref
          links[tag[:name]] = { '$ref' => "#/components/links/#{tag[:ref_name]}" }
          return
        end
        link_obj = {}
        link_obj['description'] = tag[:description] if tag[:description] && !tag[:description].empty?
        apply_link_pairs(link_obj, tag[:options])
        links[tag[:name]] = link_obj
      end

      # Applies operation callback tags onto the operation hash.
      #
      # @param tag [Hash] parsed tag entry
      # @param op [Hash] OpenAPI operation hash
      # @return [void]
      def apply_callback_tag(tag, op)
        case tag[:type]
        when :callback
          cbs = (op['callbacks'] ||= {})
          ((cbs[tag[:name]] ||= {})[tag[:url]] ||= {})[tag[:method]] ||= {
            'responses' => { '200' => { 'description' => 'OK' } }
          }
        when :callback_ref
          (op['callbacks'] ||= {})[tag[:name]] = { '$ref' => "#/components/callbacks/#{tag[:ref_name]}" }
        else
          attach_operation_callback_body_or_response(tag, last_callback_operation(op['callbacks']))
        end
      end

      # Attaches a callback request body or response onto `cb_op`.
      #
      # @param tag [Hash] parsed callback tag
      # @param cb_op [Hash, nil] active callback operation hash
      # @return [void]
      def attach_operation_callback_body_or_response(tag, cb_op)
        return unless cb_op

        if tag[:type] == :callback_request_body
          ref_schema = { '$ref' => "#/components/schemas/#{tag[:schema_name]}" }
          rb = { 'content' => { tag[:media_type] => { 'schema' => ref_schema } } }
          rb['description'] = tag[:description] if tag[:description] && !tag[:description].empty?
          cb_op['requestBody'] = rb
        else
          cb_op['responses'][tag[:status]] = build_response_object(tag[:schema_name], tag[:media_type],
                                                                   tag[:options], tag[:description])
        end
      end

      # Applies metadata, security, and server tags onto the operation context.
      #
      # @param tag [Hash] parsed tag entry
      # @param ctx [Hash] operation builder context
      # @return [void]
      def apply_meta_or_server_tag(tag, ctx)
        case tag[:type]
        when :security
          ctx[:security] << (tag[:scheme] ? { tag[:scheme] => tag[:scopes] } : {})
        when :tag
          ctx[:tags] << tag[:value]
        when :op_server
          srv = { 'url' => tag[:url] }
          srv['description'] = tag[:description] if tag[:description] && !tag[:description].empty?
          ctx[:servers] << srv
        when :op_server_var
          apply_op_server_var(tag, ctx[:servers])
        else
          apply_scalar_meta_tag(tag, ctx)
        end
      end

      # Applies scalar metadata tags (`:operationId`, `:summary`, `:description`, `:deprecated`, etc.).
      #
      # @param tag [Hash] parsed tag entry
      # @param ctx [Hash] operation builder context
      # @return [void]
      def apply_scalar_meta_tag(tag, ctx)
        op = ctx[:op]
        case tag[:type]
        when :operationId then op['operationId'] = tag[:value]
        when :summary then op['summary'] = tag[:value]
        when :description then op['description'] = tag[:value]
        when :deprecated then op['deprecated'] = true
        when :external_docs
          ed = { 'url' => tag[:url] }
          ed['description'] = tag[:description] if tag[:description] && !tag[:description].empty?
          op['externalDocs'] = ed
        when :path_summary
          ctx[:ir].openapi_spec['paths'][ctx[:path]]['summary'] = tag[:value]
        else
          ctx[:ir].openapi_spec['paths'][ctx[:path]]['description'] = tag[:value]
        end
      end

      # Attaches an operation-level server variable to the operation's `servers` array.
      #
      # @param tag [Hash] parsed `:op_server_var` tag
      # @param servers [Array<Hash>] operation servers list
      # @return [void]
      def apply_op_server_var(tag, servers)
        server = servers.find { |s| s['url'] == tag[:url] }
        unless server
          server = { 'url' => tag[:url] }
          servers << server
        end
        server['variables'] ||= {}
        pairs, parsed_rest = parse_rest(tag[:rest])
        var_obj = { 'default' => tag[:default_val] }
        var_obj['enum'] = pairs['enum'].split(',') if pairs['enum']
        var_obj['description'] = parsed_rest.strip unless parsed_rest.empty?
        server['variables'][tag[:var_name]] = var_obj
      end

      # Auto-extracts `{param}` placeholders from the route path into `params` if not already declared.
      #
      # @param path [String] route path template
      # @param params [Array<Hash>] operation parameters array
      # @return [void]
      def extract_implicit_path_params(path, params)
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
      end
    end

    # Parser for extracting OpenAPI 3.2.0 metadata, components, and operations from docstring comments.
    class Parser
      extend TagHelpers
      extend ComponentAttacher
      extend OperationAttacher

      # Primitive JSON Schema types recognized inline without `$ref` wrapping.
      PRIMITIVE_TYPES = TagHelpers::PRIMITIVE_TYPES

      # Parses docstring comments from Ripper tokens and populates the IR.
      #
      # @param tokens [Array<Array>] Ripper lexed token array
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.parse(tokens, ir)
        current_tags = []
        tokens.each do |token|
          if token[1] == :on_comment
            dispatch_comment(token[2], current_tags, ir)
          elsif !%i[on_sp on_nl on_ignored_nl].include?(token[1])
            current_tags.clear
          end
        end
      end

      # Dispatches a single comment line to the appropriate tag parser group.
      #
      # @param comment [String] raw comment line
      # @param current_tags [Array<Hash>] accumulated operation tags
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.dispatch_comment(comment, current_tags, ir)
        return if parse_server_tags?(comment, current_tags, ir)
        return if parse_schema_tags?(comment, ir)
        return if parse_component_tags?(comment, ir)
        return if parse_operation_tags?(comment, current_tags, ir)

        return unless comment =~ /#\s*@(route|webhook)\s+([A-Z]+)\s+(\S+)/i

        build_operation_from_tags(
          ::Regexp.last_match(1).downcase == 'webhook',
          ::Regexp.last_match(2).downcase,
          ::Regexp.last_match(3),
          current_tags,
          ir
        )
      end

      # Parses global and operation-level server and route-ref tags.
      #
      # @param comment [String] raw comment line
      # @param current_tags [Array<Hash>] accumulated operation tags
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [Boolean] true if the comment matched a server/route_ref tag
      def self.parse_server_tags?(comment, current_tags, ir)
        case comment
        when /#\s*@server\s+(\S+)\s*(.*)/
          ir.openapi_spec['servers'] ||= []
          ir.openapi_spec['servers'] << { 'url' => ::Regexp.last_match(1),
                                          'description' => ::Regexp.last_match(2).strip }
        when /#\s*@server_var\s+(\S+)\s+(\w+)\s+(\S+)(?:\s+(.*))?/
          attach_server_variable(ir, ::Regexp.last_match(1), ::Regexp.last_match(2),
                                 ::Regexp.last_match(3), ::Regexp.last_match(4) || '')
        when /#\s*@op_server_var\s+(\S+)\s+(\w+)\s+(\S+)(?:\s+(.*))?/
          current_tags << { type: :op_server_var, url: ::Regexp.last_match(1), var_name: ::Regexp.last_match(2),
                            default_val: ::Regexp.last_match(3), rest: ::Regexp.last_match(4) || '' }
        when /#\s*@op_server\s+(\S+)(?:\s+(.*))?/
          desc = ::Regexp.last_match(2)
          current_tags << { type: :op_server, url: ::Regexp.last_match(1).strip,
                            description: (desc && !desc.strip.empty? ? desc.strip : nil) }
        when /#\s*@route_ref\s+(\S+)\s+(\w+)/
          ir.openapi_spec['paths'] ||= {}
          ir.openapi_spec['paths'][::Regexp.last_match(1)] =
            { '$ref' => "#/components/pathItems/#{::Regexp.last_match(2)}" }
        else
          return false
        end
        true
      end

      # Attaches a parsed `@server_var` variable definition to a matching global server entry.
      #
      # @param ir [Cdd::IR] Intermediate Representation
      # @param url [String] server URL
      # @param var_name [String] variable name
      # @param default_val [String] default value
      # @param rest [String] trailing options and description
      # @return [void]
      def self.attach_server_variable(ir, url, var_name, default_val, rest)
        pairs, parsed_rest = parse_rest(rest)
        server = (ir.openapi_spec['servers'] ||= []).find { |s| s['url'] == url }
        return unless server

        server['variables'] ||= {}
        var_obj = { 'default' => default_val }
        var_obj['enum'] = pairs['enum'].split(',') if pairs['enum']
        var_obj['description'] = parsed_rest.strip unless parsed_rest.empty?
        server['variables'][var_name] = var_obj
      end

      # Parses operation-level tags and appends them to `current_tags`.
      #
      # @param comment [String] raw comment line
      # @param current_tags [Array<Hash>] accumulated operation tags
      # @param _ir [Cdd::IR] Intermediate Representation
      # @return [Boolean] true if matched
      def self.parse_operation_tags?(comment, current_tags, _ir)
        return true if parse_param_and_body_tags?(comment, current_tags)
        return true if parse_response_and_link_tags?(comment, current_tags)
        return true if parse_callback_and_meta_tags?(comment, current_tags)

        false
      end

      # Parses `@param*` and `@request_body*` tags into `current_tags`.
      #
      # @param comment [String] raw comment line
      # @param current_tags [Array<Hash>] accumulated operation tags
      # @return [Boolean] true if matched
      def self.parse_param_and_body_tags?(comment, current_tags)
        case comment
        when /#\s*@param\s+(\w+)\s+\[(\w+)\]\s+in:(\w+)(?:\s+(.*))?/
          pairs, parsed_rest = parse_rest(::Regexp.last_match(4) || '')
          current_tags << { type: :param, name: ::Regexp.last_match(1), schema_type: ::Regexp.last_match(2),
                            in: ::Regexp.last_match(3), options: pairs, description: parsed_rest.strip }
        when /#\s*@param_ref\s+(\w+)/
          current_tags << { type: :param_ref, name: ::Regexp.last_match(1).strip }
        when /#\s*@param_example_ref\s+(\w+)\s+(\w+)\s+(\w+)/
          current_tags << { type: :param_example_ref, param_name: ::Regexp.last_match(1),
                            example_name: ::Regexp.last_match(2), ref_name: ::Regexp.last_match(3) }
        when /#\s*@request_body_encoding\s+(\S+)\s+(\S+)(?:\s+(.*))?/
          pairs, parsed_rest = parse_rest(::Regexp.last_match(3) || '')
          current_tags << { type: :request_body_encoding, media_type: ::Regexp.last_match(1),
                            property: ::Regexp.last_match(2), options: pairs, description: parsed_rest.strip }
        when /#\s*@request_body_example_ref\s+(\S+)\s+(\w+)\s+(\w+)/
          current_tags << { type: :request_body_example_ref, media_type: ::Regexp.last_match(1),
                            example_name: ::Regexp.last_match(2), ref_name: ::Regexp.last_match(3) }
        when /#\s*@request_body_ref\s+(\w+)/
          current_tags << { type: :request_body_ref, name: ::Regexp.last_match(1).strip }
        when /#\s*@request_body\s+\[(\w+)\]\s+(\S+)(?:\s+(.*))?/
          pairs, parsed_rest = parse_rest(::Regexp.last_match(3) || '')
          current_tags << { type: :request_body, schema_name: ::Regexp.last_match(1),
                            media_type: ::Regexp.last_match(2), options: pairs, description: parsed_rest.strip }
        else
          return false
        end
        true
      end

      # Parses `@response*` and `@link*` tags into `current_tags`.
      #
      # @param comment [String] raw comment line
      # @param current_tags [Array<Hash>] accumulated operation tags
      # @return [Boolean] true if matched
      def self.parse_response_and_link_tags?(comment, current_tags)
        case comment
        when /#\s*@response_example_ref\s+(\d+|default)\s+(\S+)\s+(\w+)\s+(\w+)/
          current_tags << { type: :response_example_ref, status: ::Regexp.last_match(1),
                            media_type: ::Regexp.last_match(2), example_name: ::Regexp.last_match(3),
                            ref_name: ::Regexp.last_match(4) }
        when /#\s*@response_header_ref\s+(\d+|default)\s+([A-Za-z0-9_-]+)\s+(\w+)/
          current_tags << { type: :response_header_ref, status: ::Regexp.last_match(1),
                            name: ::Regexp.last_match(2), ref_name: ::Regexp.last_match(3) }
        when /#\s*@response_header\s+(\d+|default)\s+([A-Za-z0-9_-]+)\s+\[(\w+)\](?:\s+(.*))?/
          pairs, parsed_rest = parse_rest(::Regexp.last_match(4) || '')
          current_tags << { type: :response_header, status: ::Regexp.last_match(1), name: ::Regexp.last_match(2),
                            schema_type: ::Regexp.last_match(3), options: pairs, description: parsed_rest.strip }
        when /#\s*@response_ref\s+(\d+|default)\s+(\w+)/
          current_tags << { type: :response_ref, status: ::Regexp.last_match(1), name: ::Regexp.last_match(2).strip }
        when /#\s*@response\s+(\d+|default)(?:\s+\[(\w+)\]\s+(\S+))?(?:\s+(.*))?/
          pairs, parsed_rest = parse_rest(::Regexp.last_match(4) || '')
          current_tags << { type: :response, status: ::Regexp.last_match(1), schema_name: ::Regexp.last_match(2),
                            media_type: ::Regexp.last_match(3), options: pairs, description: parsed_rest.strip }
        when /#\s*@link_ref\s+(\d+|default)\s+(\w+)\s+(\w+)/
          current_tags << { type: :link_ref, status: ::Regexp.last_match(1), name: ::Regexp.last_match(2),
                            ref_name: ::Regexp.last_match(3) }
        when /#\s*@link\s+(\d+|default)\s+(\w+)(?:\s+(.*))?/
          pairs, parsed_rest = parse_rest(::Regexp.last_match(3) || '')
          current_tags << { type: :link, status: ::Regexp.last_match(1), name: ::Regexp.last_match(2),
                            options: pairs, description: parsed_rest.strip }
        else
          return false
        end
        true
      end

      # Parses `@callback*`, `@security`, and operation metadata tags into `current_tags`.
      #
      # @param comment [String] raw comment line
      # @param current_tags [Array<Hash>] accumulated operation tags
      # @return [Boolean] true if matched
      def self.parse_callback_and_meta_tags?(comment, current_tags)
        case comment
        when /#\s*@security\b(?:\s+(\w+))?(?:\s+(.*))?/
          scheme = ::Regexp.last_match(1)
          scopes = ::Regexp.last_match(2).to_s.strip.empty? ? [] : ::Regexp.last_match(2).split(/\s*,\s*/)
          current_tags << { type: :security, scheme: scheme, scopes: scheme ? scopes : [] }
        when /#\s*@callback_ref\s+(\w+)\s+(\w+)/
          current_tags << { type: :callback_ref, name: ::Regexp.last_match(1), ref_name: ::Regexp.last_match(2) }
        when /#\s*@callback\s+(\w+)\s+(\S+)\s+(get|put|post|delete|options|head|patch|trace|query)/i
          current_tags << { type: :callback, name: ::Regexp.last_match(1), url: ::Regexp.last_match(2),
                            method: ::Regexp.last_match(3).downcase }
        when /#\s*@callback_request_body\s+\[(\w+)\]\s+(\S+)(?:\s+(.*))?/
          desc = ::Regexp.last_match(3)
          current_tags << { type: :callback_request_body, schema_name: ::Regexp.last_match(1),
                            media_type: ::Regexp.last_match(2),
                            description: (desc && !desc.strip.empty? ? desc.strip : nil) }
        when /#\s*@callback_response\s+(\d+|default)(?:\s+\[(\w+)\]\s+(\S+))?(?:\s+(.*))?/
          pairs, parsed_rest = parse_rest(::Regexp.last_match(4) || '')
          current_tags << { type: :callback_response, status: ::Regexp.last_match(1),
                            schema_name: ::Regexp.last_match(2), media_type: ::Regexp.last_match(3),
                            options: pairs, description: parsed_rest.strip }
        else
          return parse_metadata_tags?(comment, current_tags)
        end
        true
      end

      # Parses `@operationId`, `@tag`, `@summary`, `@description`, `@deprecated`, `@external_docs`, and `@path_*` tags.
      #
      # @param comment [String] raw comment line
      # @param current_tags [Array<Hash>] accumulated operation tags
      # @return [Boolean] true if matched
      def self.parse_metadata_tags?(comment, current_tags)
        case comment
        when /#\s*@operationId\s+(.*)/
          current_tags << { type: :operationId, value: ::Regexp.last_match(1).strip }
        when /#\s*@tag\s+(.*)/
          current_tags << { type: :tag, value: ::Regexp.last_match(1).strip }
        when /#\s*@summary\s+(.*)/
          current_tags << { type: :summary, value: ::Regexp.last_match(1).strip }
        when /#\s*@description\s+(.*)/
          current_tags << { type: :description, value: ::Regexp.last_match(1).strip }
        when /#\s*@deprecated/
          current_tags << { type: :deprecated }
        when /#\s*@external_docs\s+(\S+)(?:\s+(.*))?/
          desc = ::Regexp.last_match(2)
          current_tags << { type: :external_docs, url: ::Regexp.last_match(1).strip,
                            description: (desc && !desc.strip.empty? ? desc.strip : nil) }
        when /#\s*@path_summary\s+(.*)/
          current_tags << { type: :path_summary, value: ::Regexp.last_match(1).strip }
        when /#\s*@path_description\s+(.*)/
          current_tags << { type: :path_description, value: ::Regexp.last_match(1).strip }
        else
          return false
        end
        true
      end
    end
  end
end
