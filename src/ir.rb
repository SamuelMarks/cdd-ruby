# frozen_string_literal: true

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Intermediate Representation of a Codebase and its OpenAPI 3.2.0 model.
  class IR
    # Strongly-typed representation of OpenAPI Info metadata.
    Info = Data.define(:title, :version, :summary, :description, :terms_of_service, :contact, :license)

    # Strongly-typed representation of an OpenAPI Server Variable.
    ServerVariable = Data.define(:default, :enum, :description)

    # Strongly-typed representation of an OpenAPI Server entry.
    Server = Data.define(:url, :description, :variables)

    # Strongly-typed representation of an OpenAPI Schema property.
    Property = Data.define(:name, :type, :description, :example, :ref)

    # Strongly-typed representation of an OpenAPI Schema component.
    Schema = Data.define(:name, :type, :properties, :required, :all_of, :one_of, :any_of, :discriminator, :xml,
                         :example, :description)

    # Strongly-typed representation of an OpenAPI Parameter.
    Parameter = Data.define(:name, :in_location, :schema, :required, :description, :style, :explode,
                            :allow_reserved, :allow_empty_value, :deprecated, :examples)

    # Strongly-typed representation of an OpenAPI Encoding object.
    Encoding = Data.define(:content_type, :headers, :style, :explode, :allow_reserved, :description)

    # Strongly-typed representation of an OpenAPI MediaType object.
    MediaType = Data.define(:schema, :example, :examples, :encoding)

    # Strongly-typed representation of an OpenAPI RequestBody object.
    RequestBody = Data.define(:description, :content, :required)

    # Strongly-typed representation of an OpenAPI Header object.
    Header = Data.define(:description, :schema, :required, :deprecated, :example, :examples)

    # Strongly-typed representation of an OpenAPI Link object.
    Link = Data.define(:operation_ref, :operation_id, :parameters, :request_body, :description, :server)

    # Strongly-typed representation of an OpenAPI Response object.
    Response = Data.define(:status, :description, :headers, :content, :links)

    # Strongly-typed representation of an OpenAPI Operation object.
    Operation = Data.define(:http_method, :path, :operation_id, :summary, :description, :tags, :parameters,
                            :request_body, :responses, :callbacks, :security, :servers, :deprecated, :external_docs)

    # Strongly-typed representation of an OpenAPI PathItem object.
    PathItem = Data.define(:path, :summary, :description, :operations, :parameters, :servers, :ref)

    # Strongly-typed representation of an OpenAPI OAuthFlows object.
    OAuthFlows = Data.define(:implicit, :password, :client_credentials, :authorization_code, :device_authorization)

    # Strongly-typed representation of an OpenAPI SecurityScheme object.
    SecurityScheme = Data.define(:name, :type, :description, :param_name, :in_location, :scheme, :bearer_format,
                                 :flows, :open_id_connect_url, :oauth2_metadata_url)

    # Strongly-typed representation of an OpenAPI Example object.
    Example = Data.define(:name, :schema_ref, :summary, :description, :value, :data_value, :serialized_value,
                          :external_value)

    # List of parsed class names, route definitions, OpenAPI specification hash, tests, and mocks.
    # @return [Array, Hash]
    attr_accessor :classes, :routes, :openapi_spec, :tests, :mocks

    # Initializes a new Intermediate Representation instance.
    #
    # @param openapi_spec [Hash, nil] optional initial OpenAPI specification hash
    # @return [Cdd::IR]
    def initialize(openapi_spec = nil)
      @classes = []
      @routes = []
      @openapi_spec = openapi_spec || {
        'openapi' => '3.2.0',
        'info' => { 'title' => 'Generated API', 'version' => '0.0.3' },
        'paths' => {},
        'components' => { 'schemas' => {} }
      }
      @tests = []
      @mocks = []
    end

    # Constructs a Cdd::IR instance from a raw OpenAPI specification Hash.
    #
    # @param hash [Hash] raw OpenAPI specification
    # @return [Cdd::IR] populated IR instance
    def self.from_openapi_hash(hash)
      ir = new(hash)
      components = hash['components']
      schemas = components['schemas'] if components.is_a?(Hash)
      ir.classes = schemas.keys if schemas.is_a?(Hash)
      ir
    end

    # Returns the OpenAPI specification Hash representation.
    #
    # @return [Hash] OpenAPI specification Hash
    def to_openapi_hash
      @openapi_spec
    end

    # Builds a typed Info value object from the current OpenAPI spec.
    #
    # @return [Cdd::IR::Info] typed info metadata
    def typed_info
      raw = @openapi_spec['info'] || {}
      Info.new(
        title: raw['title'] || 'Generated API',
        version: raw['version'] || '0.0.3',
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
            ref: p['$ref']
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
          description: s['description']
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
        'mocks' => @mocks
      }
    end
  end
end
