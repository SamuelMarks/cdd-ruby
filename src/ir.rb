# frozen_string_literal: true

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Intermediate Representation of a Codebase, its OpenAPI 3.2.0 model, and its Arazzo 1.1.0 workflows.
  class IR
    # Strongly-typed representation of OpenAPI Info metadata.
    Info = Data.define(:title, :version, :summary, :description, :terms_of_service, :contact, :license)

    # Strongly-typed representation of an OpenAPI Server Variable.
    ServerVariable = Data.define(:default, :enum, :description)

    # Strongly-typed representation of an OpenAPI Server entry.
    Server = Data.define(:url, :description, :variables)

    # Strongly-typed representation of an OpenAPI Schema property.
    Property = Data.define(:name, :type, :description, :example, :ref, :read_only)

    # Strongly-typed representation of an OpenAPI Schema component.
    Schema = Data.define(:name, :type, :properties, :required, :all_of, :one_of, :any_of, :discriminator, :xml,
                         :example, :description, :read_only)

    # Strongly-typed representation of an OpenAPI Parameter.
    Parameter = Data.define(:name, :in_location, :schema, :required, :description, :style, :explode,
                            :allow_reserved, :allow_empty_value, :deprecated, :examples, :collection_format, :items)

    # Strongly-typed representation of an OpenAPI Encoding object.
    Encoding = Data.define(:content_type, :headers, :style, :explode, :allow_reserved, :description,
                           :prefix_encoding, :item_encoding)

    # Strongly-typed representation of an OpenAPI MediaType object.
    MediaType = Data.define(:schema, :item_schema, :example, :examples, :encoding, :prefix_encoding, :item_encoding)

    # Strongly-typed representation of an OpenAPI RequestBody object.
    RequestBody = Data.define(:description, :content, :required)

    # Strongly-typed representation of an OpenAPI Header object.
    Header = Data.define(:description, :schema, :required, :deprecated, :example, :examples, :collection_format, :items)

    # Strongly-typed representation of an OpenAPI Link object.
    Link = Data.define(:operation_ref, :operation_id, :parameters, :request_body, :description, :server)

    # Strongly-typed representation of an OpenAPI Response object.
    Response = Data.define(:status, :description, :headers, :content, :links)

    # Strongly-typed representation of an OpenAPI Operation object.
    Operation = Data.define(:http_method, :path, :operation_id, :summary, :description, :tags, :parameters,
                            :request_body, :responses, :callbacks, :security, :servers, :deprecated, :external_docs,
                            :produces)

    # Strongly-typed representation of an OpenAPI PathItem object.
    PathItem = Data.define(:path, :summary, :description, :operations, :additional_operations, :parameters, :servers,
                           :ref)

    # Strongly-typed representation of an OpenAPI OAuthFlows object.
    OAuthFlows = Data.define(:implicit, :password, :client_credentials, :authorization_code, :device_authorization)

    # Strongly-typed representation of an OpenAPI SecurityScheme object.
    SecurityScheme = Data.define(:name, :type, :description, :param_name, :in_location, :scheme, :bearer_format,
                                 :flows, :open_id_connect_url, :oauth2_metadata_url, :authorization_url)

    # Strongly-typed representation of an OpenAPI Example object.
    Example = Data.define(:name, :schema_ref, :summary, :description, :value, :data_value, :serialized_value,
                          :external_value)

    # Strongly-typed representation of the root Arazzo 1.1.0 Specification Object.
    ArazzoSpec = Data.define(:arazzo, :self_uri, :info, :source_descriptions, :workflows, :components, :extensions)

    # Strongly-typed representation of an Arazzo 1.1.0 Info Object.
    ArazzoInfo = Data.define(:title, :summary, :description, :version, :extensions)

    # Strongly-typed representation of an Arazzo 1.1.0 Source Description Object.
    SourceDescription = Data.define(:name, :url, :type, :extensions)

    # Strongly-typed representation of an Arazzo 1.1.0 Workflow Object.
    Workflow = Data.define(:workflow_id, :summary, :description, :inputs, :depends_on, :steps, :success_actions,
                           :failure_actions, :outputs, :parameters, :extensions)

    # Strongly-typed representation of an Arazzo 1.1.0 Step Object.
    Step = Data.define(:step_id, :description, :operation_id, :operation_path, :channel_path, :workflow_id,
                       :parameters, :request_body, :success_criteria, :on_success, :on_failure, :outputs,
                       :timeout, :correlation_id, :action, :depends_on, :extensions)

    # Strongly-typed representation of an Arazzo 1.1.0 Parameter Object.
    ArazzoParameter = Data.define(:name, :in_location, :value, :extensions)

    # Strongly-typed representation of an Arazzo 1.1.0 Reusable Object (`reference` + optional `value`).
    ReusableObject = Data.define(:reference, :value)

    # Strongly-typed representation of an Arazzo 1.1.0 Success Action Object.
    SuccessAction = Data.define(:name, :type, :workflow_id, :step_id, :parameters, :criteria, :extensions)

    # Strongly-typed representation of an Arazzo 1.1.0 Failure Action Object.
    FailureAction = Data.define(:name, :type, :workflow_id, :step_id, :parameters, :retry_after, :retry_limit,
                                :criteria, :extensions)

    # Strongly-typed representation of an Arazzo 1.1.0 Criterion Object.
    Criterion = Data.define(:context, :condition, :type, :extensions)

    # Strongly-typed representation of an Arazzo 1.1.0 Criterion Expression Type Object.
    ExpressionType = Data.define(:type, :version, :extensions)

    # Strongly-typed representation of an Arazzo 1.1.0 Selector Object for dynamic output extraction.
    Selector = Data.define(:context, :selector, :type, :extensions)

    # Strongly-typed representation of an Arazzo 1.1.0 Request Body Object.
    ArazzoRequestBody = Data.define(:content_type, :payload, :replacements, :extensions)

    # Strongly-typed representation of an Arazzo 1.1.0 Payload Replacement Object.
    PayloadReplacement = Data.define(:target, :target_selector_type, :value, :extensions)

    # Strongly-typed representation of an Arazzo 1.1.0 Components Object.
    ArazzoComponents = Data.define(:inputs, :parameters, :success_actions, :failure_actions, :extensions)

    # List of parsed class names, routes, OpenAPI spec, tests, mocks, Arazzo spec, and workflow IDs.
    # @return [Array, Hash]
    attr_accessor :classes, :routes, :openapi_spec, :tests, :mocks, :arazzo_spec, :workflows

    # Initializes a new Intermediate Representation instance.
    #
    # @param openapi_spec [Hash, nil] optional initial OpenAPI specification hash
    # @param arazzo_spec [Hash, nil] optional initial Arazzo specification hash
    # @return [Cdd::IR]
    def initialize(openapi_spec = nil, arazzo_spec = nil)
      @classes = []
      @routes = []
      @openapi_spec = openapi_spec || {
        'openapi' => '3.2.0',
        'info' => { 'title' => 'Generated API', 'version' => '0.0.4' },
        'paths' => {},
        'components' => { 'schemas' => {} }
      }
      @arazzo_spec = arazzo_spec || {
        'arazzo' => '1.1.0',
        'info' => { 'title' => 'Generated Workflows', 'version' => '0.0.4' },
        'sourceDescriptions' => [],
        'workflows' => []
      }
      @tests = []
      @mocks = []
      @workflows = []
    end

    # Constructs a Cdd::IR instance from a raw OpenAPI specification Hash.
    #
    # @param hash [Hash] raw OpenAPI specification
    # @return [Cdd::IR] populated IR instance
    def self.from_openapi_hash(hash)
      ir = new(hash)
      components = hash['components']
      if components.is_a?(Hash)
        ir.classes = components['schemas'].keys if components['schemas'].is_a?(Hash)
        ir.mocks = components['examples'].keys if components['examples'].is_a?(Hash)
      end
      if hash['paths'].is_a?(Hash)
        hash['paths'].each do |path, methods|
          methods.each do |verb, op_val|
            next if %w[$ref summary description servers parameters].include?(verb)

            if verb == 'additionalOperations' && op_val.is_a?(Hash)
              op_val.each_key { |add_verb| ir.routes |= ["#{add_verb.upcase} #{path}"] }
            else
              ir.routes |= ["#{verb.upcase} #{path}"]
            end
          end
        end
      end
      ir
    end

    # Constructs a Cdd::IR instance from a raw Arazzo 1.0.x/1.1.0 specification Hash.
    #
    # @param hash [Hash] raw Arazzo specification
    # @return [Cdd::IR] populated IR instance
    # @raise [Cdd::ArazzoValidationError] when the Arazzo version is missing or unsupported
    def self.from_arazzo_hash(hash)
      raise Cdd::ArazzoValidationError, 'Arazzo spec must be a Hash' unless hash.is_a?(Hash)

      version = hash['arazzo'].to_s
      unless version.match?(/\A1\.[01]\.\d+\z/)
        raise Cdd::ArazzoValidationError, "Unsupported or missing Arazzo version: #{version.inspect}"
      end

      ir = new(nil, hash)
      wfs = hash['workflows']
      ir.workflows = wfs.filter_map { |wf| wf['workflowId'] if wf.is_a?(Hash) } if wfs.is_a?(Array)
      ir
    end

    # Extracts `^x-` vendor extension keys from a raw specification Hash.
    #
    # @param raw [Hash, nil] raw specification object hash
    # @return [Hash{String => Object}] vendor extension entries
    def self.extract_extensions(raw)
      return {} unless raw.is_a?(Hash)

      raw.select { |k, _| k.to_s.start_with?('x-') }
    end

    # Builds a typed `ArazzoParameter` or `ReusableObject` from a raw parameter Hash.
    #
    # @param raw [Hash] raw parameter or reusable reference hash
    # @return [Cdd::IR::ArazzoParameter, Cdd::IR::ReusableObject] typed parameter node
    def self.build_arazzo_param_or_ref(raw)
      if raw['reference']
        ReusableObject.new(reference: raw['reference'], value: raw['value'])
      else
        ArazzoParameter.new(
          name: raw['name'],
          in_location: raw['in'],
          value: raw['value'],
          extensions: extract_extensions(raw)
        )
      end
    end

    # Builds a typed `Criterion` from a raw criterion Hash.
    #
    # @param raw [Hash] raw criterion hash
    # @return [Cdd::IR::Criterion] typed criterion node
    def self.build_criterion(raw)
      ctype = raw['type']
      typed_type = if ctype.is_a?(Hash)
                     ExpressionType.new(
                       type: ctype['type'],
                       version: ctype['version'],
                       extensions: extract_extensions(ctype)
                     )
                   else
                     ctype
                   end
      Criterion.new(
        context: raw['context'],
        condition: raw['condition'],
        type: typed_type,
        extensions: extract_extensions(raw)
      )
    end

    # Builds a typed `SuccessAction` or `ReusableObject` from a raw action Hash.
    #
    # @param raw [Hash] raw success action hash
    # @return [Cdd::IR::SuccessAction, Cdd::IR::ReusableObject] typed success action node
    def self.build_success_action(raw)
      return ReusableObject.new(reference: raw['reference'], value: raw['value']) if raw['reference']

      SuccessAction.new(
        name: raw['name'],
        type: raw['type'],
        workflow_id: raw['workflowId'],
        step_id: raw['stepId'],
        parameters: (raw['parameters'] || []).map { |p| build_arazzo_param_or_ref(p) },
        criteria: (raw['criteria'] || []).map { |c| build_criterion(c) },
        extensions: extract_extensions(raw)
      )
    end

    # Builds a typed `FailureAction` or `ReusableObject` from a raw action Hash.
    #
    # @param raw [Hash] raw failure action hash
    # @return [Cdd::IR::FailureAction, Cdd::IR::ReusableObject] typed failure action node
    def self.build_failure_action(raw)
      return ReusableObject.new(reference: raw['reference'], value: raw['value']) if raw['reference']

      FailureAction.new(
        name: raw['name'],
        type: raw['type'],
        workflow_id: raw['workflowId'],
        step_id: raw['stepId'],
        parameters: (raw['parameters'] || []).map { |p| build_arazzo_param_or_ref(p) },
        retry_after: raw['retryAfter'],
        retry_limit: raw['retryLimit'],
        criteria: (raw['criteria'] || []).map { |c| build_criterion(c) },
        extensions: extract_extensions(raw)
      )
    end

    # Builds a typed output value (String runtime expression or `Selector` object).
    #
    # @param val [String, Hash] raw output expression or selector hash
    # @return [String, Cdd::IR::Selector] typed output representation
    def self.build_output_value(val)
      return val unless val.is_a?(Hash)

      stype = val['type']
      typed_type = if stype.is_a?(Hash)
                     ExpressionType.new(
                       type: stype['type'],
                       version: stype['version'],
                       extensions: extract_extensions(stype)
                     )
                   else
                     stype
                   end
      Selector.new(
        context: val['context'],
        selector: val['selector'],
        type: typed_type,
        extensions: extract_extensions(val)
      )
    end

    # Builds a typed `ArazzoRequestBody` from a raw requestBody Hash.
    #
    # @param raw [Hash, nil] raw request body hash
    # @return [Cdd::IR::ArazzoRequestBody, nil] typed request body or nil
    def self.build_arazzo_request_body(raw)
      return nil unless raw.is_a?(Hash)

      replacements = (raw['replacements'] || []).map do |rep|
        PayloadReplacement.new(
          target: rep['target'],
          target_selector_type: rep['targetSelectorType'],
          value: rep['value'],
          extensions: extract_extensions(rep)
        )
      end
      ArazzoRequestBody.new(
        content_type: raw['contentType'],
        payload: raw['payload'],
        replacements: replacements,
        extensions: extract_extensions(raw)
      )
    end

    # Builds a typed `Step` from a raw step Hash.
    #
    # @param raw [Hash] raw step hash
    # @return [Cdd::IR::Step] typed step node
    def self.build_step(raw)
      Step.new(
        step_id: raw['stepId'],
        description: raw['description'],
        operation_id: raw['operationId'],
        operation_path: raw['operationPath'],
        channel_path: raw['channelPath'],
        workflow_id: raw['workflowId'],
        parameters: (raw['parameters'] || []).map { |p| build_arazzo_param_or_ref(p) },
        request_body: build_arazzo_request_body(raw['requestBody']),
        success_criteria: (raw['successCriteria'] || []).map { |c| build_criterion(c) },
        on_success: (raw['onSuccess'] || []).map { |a| build_success_action(a) },
        on_failure: (raw['onFailure'] || []).map { |a| build_failure_action(a) },
        outputs: (raw['outputs'] || {}).transform_values { |v| build_output_value(v) },
        timeout: raw['timeout'],
        correlation_id: raw['correlationId'],
        action: raw['action'],
        depends_on: raw['dependsOn'],
        extensions: extract_extensions(raw)
      )
    end

    # Builds a typed `Workflow` from a raw workflow Hash.
    #
    # @param raw [Hash] raw workflow hash
    # @return [Cdd::IR::Workflow] typed workflow node
    def self.build_workflow(raw)
      Workflow.new(
        workflow_id: raw['workflowId'],
        summary: raw['summary'],
        description: raw['description'],
        inputs: raw['inputs'],
        depends_on: raw['dependsOn'],
        steps: (raw['steps'] || []).map { |s| build_step(s) },
        success_actions: (raw['successActions'] || []).map { |a| build_success_action(a) },
        failure_actions: (raw['failureActions'] || []).map { |a| build_failure_action(a) },
        outputs: (raw['outputs'] || {}).transform_values { |v| build_output_value(v) },
        parameters: (raw['parameters'] || []).map { |p| build_arazzo_param_or_ref(p) },
        extensions: extract_extensions(raw)
      )
    end

    # Builds a typed `ArazzoComponents` from a raw components Hash.
    #
    # @param raw [Hash, nil] raw components hash
    # @return [Cdd::IR::ArazzoComponents, nil] typed components node or nil
    def self.build_arazzo_components(raw)
      return nil unless raw.is_a?(Hash)

      ArazzoComponents.new(
        inputs: raw['inputs'] || {},
        parameters: (raw['parameters'] || {}).transform_values { |p| build_arazzo_param_or_ref(p) },
        success_actions: (raw['successActions'] || {}).transform_values { |a| build_success_action(a) },
        failure_actions: (raw['failureActions'] || {}).transform_values { |a| build_failure_action(a) },
        extensions: extract_extensions(raw)
      )
    end

    # Returns the OpenAPI specification Hash representation.
    #
    # @return [Hash] OpenAPI specification Hash
    def to_openapi_hash
      @openapi_spec
    end

    # Returns the Arazzo specification Hash representation.
    #
    # @return [Hash] Arazzo specification Hash
    def to_arazzo_hash
      @arazzo_spec
    end

    # Builds a typed `ArazzoSpec` value object graph from the current `@arazzo_spec`.
    #
    # @return [Cdd::IR::ArazzoSpec] strongly-typed Arazzo specification tree
    def typed_arazzo
      raw_info = @arazzo_spec['info'] || {}
      info = ArazzoInfo.new(
        title: raw_info['title'] || 'Generated Workflows',
        summary: raw_info['summary'],
        description: raw_info['description'],
        version: raw_info['version'] || Cdd::VERSION,
        extensions: self.class.extract_extensions(raw_info)
      )
      sources = (@arazzo_spec['sourceDescriptions'] || []).map do |src|
        SourceDescription.new(
          name: src['name'],
          url: src['url'],
          type: src['type'],
          extensions: self.class.extract_extensions(src)
        )
      end
      ArazzoSpec.new(
        arazzo: @arazzo_spec['arazzo'] || '1.1.0',
        self_uri: @arazzo_spec['$self'],
        info: info,
        source_descriptions: sources,
        workflows: (@arazzo_spec['workflows'] || []).map { |wf| self.class.build_workflow(wf) },
        components: self.class.build_arazzo_components(@arazzo_spec['components']),
        extensions: self.class.extract_extensions(@arazzo_spec)
      )
    end

    # Builds a typed Info value object from the current OpenAPI spec.
    #
    # @return [Cdd::IR::Info] typed info metadata
    def typed_info
      raw = @openapi_spec['info'] || {}
      Info.new(
        title: raw['title'] || 'Generated API',
        version: raw['version'] || Cdd::VERSION,
        summary: raw['summary'],
        description: raw['description'],
        terms_of_service: raw['termsOfService'],
        contact: raw['contact'],
        license: raw['license']
      )
    end

    # Builds typed Server value objects from the current OpenAPI spec.
    #
    # @return [Array<Cdd::IR::Server>] list of typed Server objects
    def typed_servers
      (@openapi_spec['servers'] || []).map do |srv|
        vars = (srv['variables'] || {}).transform_values do |v|
          ServerVariable.new(default: v['default'], enum: v['enum'], description: v['description'])
        end
        Server.new(url: srv['url'], description: srv['description'], variables: vars)
      end
    end

    # Builds typed Schema value objects from the current OpenAPI spec.
    #
    # @return [Array<Cdd::IR::Schema>] list of typed Schema objects
    def typed_schemas
      components = @openapi_spec['components']
      schemas = components.is_a?(Hash) ? (components['schemas'] || {}) : {}
      schemas.map do |name, s|
        props = (s['properties'] || {}).map do |prop_name, p|
          Property.new(
            name: prop_name,
            type: p['type'],
            description: p['description'],
            example: p['example'],
            ref: p['$ref'],
            read_only: p['readOnly']
          )
        end
        Schema.new(
          name: name,
          type: s['type'],
          properties: props,
          required: s['required'] || [],
          all_of: s['allOf'],
          one_of: s['oneOf'],
          any_of: s['anyOf'],
          discriminator: s['discriminator'],
          xml: s['xml'],
          example: s['example'],
          description: s['description'],
          read_only: s['readOnly']
        )
      end
    end

    # Builds a typed `Parameter` from a raw OpenAPI parameter Hash.
    #
    # @param raw [Hash] raw OpenAPI parameter hash
    # @return [Cdd::IR::Parameter] typed parameter object
    def self.build_parameter(raw)
      Parameter.new(
        name: raw['name'],
        in_location: raw['in'],
        schema: raw['schema'],
        required: raw['required'] || false,
        description: raw['description'],
        style: raw['style'],
        explode: raw['explode'],
        allow_reserved: raw['allowReserved'],
        allow_empty_value: raw['allowEmptyValue'],
        deprecated: raw['deprecated'],
        examples: raw['examples'],
        collection_format: raw['collectionFormat'],
        items: raw['items']
      )
    end

    # Builds a typed `Encoding` from a raw OpenAPI encoding Hash.
    #
    # @param raw [Hash] raw OpenAPI encoding hash
    # @return [Cdd::IR::Encoding] typed encoding object
    def self.build_encoding(raw)
      Encoding.new(
        content_type: raw['contentType'],
        headers: raw['headers'],
        style: raw['style'],
        explode: raw['explode'],
        allow_reserved: raw['allowReserved'],
        description: raw['description'],
        prefix_encoding: (raw['prefixEncoding'] || []).map { |pe| build_encoding(pe) },
        item_encoding: raw['itemEncoding'].is_a?(Hash) ? build_encoding(raw['itemEncoding']) : nil
      )
    end

    # Builds a typed `MediaType` from a raw OpenAPI mediaType Hash.
    #
    # @param raw [Hash] raw OpenAPI media type hash
    # @return [Cdd::IR::MediaType] typed media type object
    def self.build_media_type(raw)
      encodings = (raw['encoding'] || {}).transform_values { |enc| build_encoding(enc) }
      MediaType.new(
        schema: raw['schema'],
        item_schema: raw['itemSchema'],
        example: raw['example'],
        examples: raw['examples'],
        encoding: encodings,
        prefix_encoding: (raw['prefixEncoding'] || []).map { |pe| build_encoding(pe) },
        item_encoding: raw['itemEncoding'].is_a?(Hash) ? build_encoding(raw['itemEncoding']) : nil
      )
    end

    # Builds a typed `RequestBody` from a raw OpenAPI requestBody Hash.
    #
    # @param raw [Hash, nil] raw OpenAPI request body hash
    # @return [Cdd::IR::RequestBody, nil] typed request body or nil
    def self.build_request_body(raw)
      return nil unless raw.is_a?(Hash)

      content = (raw['content'] || {}).transform_values { |mt| build_media_type(mt) }
      RequestBody.new(
        description: raw['description'],
        content: content,
        required: raw['required']
      )
    end

    # Builds a typed `Response` from a status string and raw OpenAPI response Hash.
    #
    # @param status [String] HTTP status code
    # @param raw [Hash] raw OpenAPI response hash
    # @return [Cdd::IR::Response] typed response object
    def self.build_response(status, raw)
      headers = (raw['headers'] || {}).transform_values do |h|
        Header.new(
          description: h['description'],
          schema: h['schema'],
          required: h['required'],
          deprecated: h['deprecated'],
          example: h['example'],
          examples: h['examples'],
          collection_format: h['collectionFormat'],
          items: h['items']
        )
      end
      links = (raw['links'] || {}).transform_values do |l|
        Link.new(
          operation_ref: l['operationRef'],
          operation_id: l['operationId'],
          parameters: l['parameters'],
          request_body: l['requestBody'],
          description: l['description'],
          server: l['server']
        )
      end
      content = (raw['content'] || {}).transform_values { |mt| build_media_type(mt) }
      Response.new(
        status: status,
        description: raw['description'],
        headers: headers,
        content: content,
        links: links
      )
    end

    # Builds a typed `Operation` from a method, path, and raw OpenAPI operation Hash.
    #
    # @param http_method [String] HTTP verb
    # @param path [String] route path
    # @param raw [Hash] raw OpenAPI operation hash
    # @return [Cdd::IR::Operation] typed operation object
    def self.build_operation(http_method, path, raw)
      params = (raw['parameters'] || []).map { |p| build_parameter(p) }
      responses = (raw['responses'] || {}).to_h { |st, r| [st, build_response(st, r)] }
      Operation.new(
        http_method: http_method,
        path: path,
        operation_id: raw['operationId'],
        summary: raw['summary'],
        description: raw['description'],
        tags: raw['tags'] || [],
        parameters: params,
        request_body: build_request_body(raw['requestBody']),
        responses: responses,
        callbacks: raw['callbacks'],
        security: raw['security'],
        servers: raw['servers'],
        deprecated: raw['deprecated'],
        external_docs: raw['externalDocs'],
        produces: raw['produces']
      )
    end

    # Builds typed standard and additional `Operation` maps for a path item.
    #
    # @param path [String] route path
    # @param raw [Hash] raw OpenAPI PathItem hash
    # @return [Array(Hash, Hash)] `[operations, additional_operations]`
    def self.build_path_item_operations(path, raw)
      ops = {}
      add_ops = {}
      raw.each do |k, v|
        if k == 'additionalOperations' && v.is_a?(Hash)
          v.each { |ak, av| add_ops[ak] = build_operation(ak, path, av) }
          next
        end
        next if k.start_with?('x-') || %w[$ref summary description servers parameters].include?(k) || !v.is_a?(Hash)

        ops[k] = build_operation(k, path, v)
      end
      [ops, add_ops]
    end

    # Builds typed `PathItem` value objects from the current OpenAPI spec.
    #
    # @return [Array<Cdd::IR::PathItem>] list of typed PathItem objects
    def typed_paths
      (@openapi_spec['paths'] || {}).filter_map do |path, raw|
        next nil unless raw.is_a?(Hash)

        ops, add_ops = self.class.build_path_item_operations(path, raw)
        PathItem.new(
          path: path,
          summary: raw['summary'],
          description: raw['description'],
          operations: ops,
          additional_operations: add_ops,
          parameters: (raw['parameters'] || []).map { |p| self.class.build_parameter(p) },
          servers: raw['servers'],
          ref: raw['$ref']
        )
      end
    end

    # Builds typed `SecurityScheme` value objects from the current OpenAPI or Swagger spec.
    #
    # @return [Array<Cdd::IR::SecurityScheme>] list of typed SecurityScheme objects
    def typed_security_schemes
      comp_schemes = @openapi_spec.dig('components', 'securitySchemes')
      swag_schemes = @openapi_spec['securityDefinitions']
      schemes = (comp_schemes.is_a?(Hash) ? comp_schemes : {}).merge(swag_schemes.is_a?(Hash) ? swag_schemes : {})
      return [] if schemes.empty?

      schemes.map do |name, raw|
        raw_flows = raw['flows']
        flows = if raw_flows.is_a?(Hash)
                  OAuthFlows.new(
                    implicit: raw_flows['implicit'],
                    password: raw_flows['password'],
                    client_credentials: raw_flows['clientCredentials'],
                    authorization_code: raw_flows['authorizationCode'],
                    device_authorization: raw_flows['deviceAuthorization']
                  )
                end
        SecurityScheme.new(
          name: name,
          type: raw['type'],
          description: raw['description'],
          param_name: raw['name'],
          in_location: raw['in'],
          scheme: raw['scheme'],
          bearer_format: raw['bearerFormat'],
          flows: flows,
          open_id_connect_url: raw['openIdConnectUrl'],
          oauth2_metadata_url: raw['oauth2MetadataUrl'],
          authorization_url: raw['authorizationUrl']
        )
      end
    end

    # Builds typed `Example` value objects from the current OpenAPI spec.
    #
    # @return [Array<Cdd::IR::Example>] list of typed Example objects
    def typed_examples
      examples = @openapi_spec.dig('components', 'examples')
      return [] unless examples.is_a?(Hash)

      examples.map do |name, raw|
        schema_ref = raw['summary'].to_s[/Example for (\w+)/, 1]
        Example.new(
          name: name,
          schema_ref: schema_ref,
          summary: raw['summary'],
          description: raw['description'],
          value: raw['value'],
          data_value: raw['dataValue'],
          serialized_value: raw['serializedValue'],
          external_value: raw['externalValue']
        )
      end
    end

    # Serializes the IR state into a Hash.
    #
    # @return [Hash{String => Object}] hash representation of the IR
    def to_h
      {
        'classes' => @classes,
        'routes' => @routes,
        'openapi' => @openapi_spec,
        'tests' => @tests,
        'mocks' => @mocks,
        'arazzo' => @arazzo_spec,
        'workflows' => @workflows
      }
    end
  end
end
