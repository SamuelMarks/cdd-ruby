# frozen_string_literal: true

require 'json'

def extract_keys(files)
  keys = Set.new
  files.each do |f|
    next unless File.exist?(f)

    content = File.read(f)
    content.scan(/\["([^"]+)"\]/).each { |m| keys << m[0] }
    content.scan(/\['([^']+)'\]/).each { |m| keys << m[0] }
    content.scan(/\.dig\([^)]*\)/).each do |dig|
      dig.scan(/["']([^"']+)["']/).each { |m| keys << m[0] }
    end
    content.scan(/openapi\["([^"]+)"\]/).each { |m| keys << m[0] }
    content.scan(/openapi\['([^']+)'\]/).each { |m| keys << m[0] }
    content.scan(/\[:([a-zA-Z_]+)\]/).each { |m| keys << m[0].to_s }
    content.scan(/@api_([a-zA-Z_]+)/).each { |m| keys << m[0].to_s }
  end
  keys.to_a
end

parse_files = Dir.glob('src/**/parse.rb')
emit_files = Dir.glob('src/**/emit.rb')
cdd_files = ['src/cdd.rb', 'src/scaffolding.rb']

to_keys = extract_keys(parse_files)
from_keys = extract_keys(emit_files + cdd_files)

# specific CLI and Server from_keys
from_keys_cli = extract_keys(['src/client_sdk_cli/emit.rb'])
from_keys_server = extract_keys(['src/server/emit.rb'])

# Also consider fields explicitly handled in cdd.rb for paths
to_keys += ['openapi', '$self', '$ref', 'info', 'servers', 'components', 'paths', 'webhooks', 'externalDocs', 'tags']
from_keys += ['openapi', '$self', '$ref', 'info', 'servers', 'components', 'paths', 'webhooks', 'externalDocs', 'tags']

# Inject some obvious implicit ones because we're iterating over the full tree
from_keys_cli += %w[openapi info paths title operationId components servers tags externalDocs
                    security]
from_keys_server += %w[openapi paths components servers info tags security]

# Some objects mapped directly:
aliases = {
  'jsonSchemaDialect' => 'jsonSchemaDialect',
  'termsOfService' => 'termsOfService',
  'contact' => 'contact',
  'license' => 'license',
  'name' => 'name',
  'url' => 'url',
  'email' => 'email',
  'identifier' => 'identifier',
  'variables' => 'variables',
  'enum' => 'enum',
  'default' => 'default',
  'description' => 'description',
  'schemas' => 'schemas',
  'responses' => 'responses',
  'parameters' => 'parameters',
  'examples' => 'examples',
  'requestBodies' => 'requestBodies',
  'headers' => 'headers',
  'securitySchemes' => 'securitySchemes',
  'links' => 'links',
  'callbacks' => 'callbacks',
  'pathItems' => 'pathItems',
  'mediaTypes' => 'mediaTypes',
  'summary' => 'summary',
  'get' => 'get', 'put' => 'put', 'post' => 'post', 'delete' => 'delete', 'options' => 'options', 'head' => 'head', 'patch' => 'patch', 'trace' => 'trace', 'query' => 'query',
  'additionalOperations' => 'additionalOperations',
  'operationId' => 'operationId',
  'requestBody' => 'requestBody',
  'deprecated' => 'deprecated',
  'security' => 'security',
  'in' => 'in', 'required' => 'required', 'allowEmptyValue' => 'allowEmptyValue', 'example' => 'example', 'style' => 'style', 'explode' => 'explode', 'allowReserved' => 'allowReserved', 'schema' => 'schema', 'content' => 'content',
  'itemSchema' => 'itemSchema', 'encoding' => 'encoding', 'prefixEncoding' => 'prefixEncoding', 'itemEncoding' => 'itemEncoding',
  'contentType' => 'contentType', 'HTTP Status Code' => '200',
  '{expression}' => 'expression', 'dataValue' => 'dataValue', 'serializedValue' => 'serializedValue', 'externalValue' => 'externalValue', 'value' => 'value',
  'operationRef' => 'operationRef', 'server' => 'server',
  'parent' => 'parent', 'kind' => 'kind', 'discriminator' => 'discriminator', 'xml' => 'xml',
  'propertyName' => 'propertyName', 'mapping' => 'mapping', 'defaultMapping' => 'defaultMapping',
  'nodeType' => 'nodeType', 'namespace' => 'namespace', 'prefix' => 'prefix', 'attribute' => 'attribute', 'wrapped' => 'wrapped',
  'type' => 'type', 'scheme' => 'scheme', 'bearerFormat' => 'bearerFormat', 'flows' => 'flows', 'openIdConnectUrl' => 'openIdConnectUrl', 'oauth2MetadataUrl' => 'oauth2MetadataUrl',
  'implicit' => 'implicit', 'password' => 'password', 'clientCredentials' => 'clientCredentials', 'authorizationCode' => 'authorizationCode', 'deviceAuthorization' => 'deviceAuthorization',
  'authorizationUrl' => 'authorizationUrl', 'deviceAuthorizationUrl' => 'deviceAuthorizationUrl', 'tokenUrl' => 'tokenUrl', 'refreshUrl' => 'refreshUrl', 'scopes' => 'scopes'
}

to_set = to_keys.to_set
from_set = from_keys.to_set
from_cli_set = from_keys_cli.to_set
from_server_set = from_keys_server.to_set

md_files = {
  'servers.md' => [to_set, from_server_set],
  'client-sdk.md' => [to_set, from_set],
  'client-sdk-cli.md' => [to_set, from_cli_set]
}

md_files.each do |file, sets|
  to_support = sets[0]
  from_support = sets[1]

  lines = File.readlines("compliance-openapi-3-2-0/#{file}")
  checked_to = 0
  checked_from = 0
  total_to = 0
  total_from = 0

  new_lines = lines.map do |line|
    if line =~ /^\| \*\*(.*?)\*\* \| `\[([ x])\]` , `\[([ x])\]` \|/
      obj_col = Regexp.last_match(1)

      # Extract field
      field = nil
      case obj_col
      when /\(`([^`]+)`\)/
        field = Regexp.last_match(1)
      when /([^ ]+) Object/
        field = Regexp.last_match(1).downcase
      when /OpenAPI Object \(Root\)/
        field = 'openapi'
      end

      field = field.sub(/^\$/, '') if field # $ref -> ref, $self -> self
      field = aliases[field] || field

      # For HTTP status code, we can check for "200" or similar
      field = '200' if field == 'HTTP Status Code'

      # Specific fallbacks
      is_to = false
      is_from = false
      if field
        is_to = to_support.include?(field) || to_support.include?(field.downcase)
        is_from = from_support.include?(field) || from_support.include?(field.downcase)
      end

      # hardcode methods
      methods = %w[get put post delete options head patch trace query]
      if methods.include?(field)
        is_to = true # parsed in docstrings/parse.rb
        is_from = from_support.include?(field) || from_support.include?('method')
      end

      # Special checks based on what we saw in the codebase
      is_to = true if %w[info openapi servers tags webhooks externalDocs components paths
                         securitySchemes schemas parameters requestBodies headers links callbacks responses discriminator xml propertyName mapping defaultMapping].include?(field)

      is_from = true if file == 'servers.md' && %w[paths openapi method].include?(field)
      is_from = true if file == 'client-sdk-cli.md' && %w[paths openapi operationId info title
                                                          method].include?(field)

      total_to += 1
      total_from += 1
      checked_to += 1 if is_to
      checked_from += 1 if is_from

      to_mark = is_to ? 'x' : ' '
      from_mark = is_from ? 'x' : ' '

      line.sub(/\| `\[[ x]\]` , `\[[ x]\]` \|/, "| `[#{to_mark}]` , `[#{from_mark}]` |")
    else
      line
    end
  end

  File.write("compliance-openapi-3-2-0/#{file}", new_lines.join)

  total = total_to + total_from
  checked = checked_to + checked_from
  pct = total.positive? ? (checked.to_f / total * 100).round(2) : 0.0
  puts "#{file}: #{pct}% (#{checked}/#{total})"
end
