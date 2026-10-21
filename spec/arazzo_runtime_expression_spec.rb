# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../src/arazzo/runtime_expression'

class ArazzoRuntimeExpressionTest < Minitest::Test
  def sample_context
    {
      url: 'https://api.example.com/v1/pets',
      method: 'POST',
      status_code: 200,
      self_uri: 'https://api.example.com/arazzo.json',
      request: {
        header: { 'Authorization' => 'Bearer req-tok', 'x-custom' => 'val' },
        query: { 'filter' => 'active' },
        path: { 'petId' => '99' },
        body: { 'name' => 'Fluffy', 'tags' => %w[cute fast] }
      },
      response: {
        headers: { 'Content-Type' => 'application/json', 'Retry-After' => '5' },
        body: '{"id":42,"status":"available","items":[{"code":"A1"},{"code":"B2"}]}'
      },
      message: {
        header: { 'correlationId' => 'corr-123' },
        payload: { 'event' => 'created', 'nested' => { 'ok' => true } }
      },
      inputs: { 'username' => 'alice', 'count' => 3 },
      outputs: { 'finalId' => 42 },
      steps: {
        'loginStep' => {
          outputs: { 'token' => 'tok-xyz', 'items' => %w[x y] }
        }
      },
      workflows: {
        'authFlow' => { outputs: { 'jwt' => 'jwt-999' }, inputs: { 'env' => 'prod' } }
      },
      source_descriptions: {
        'petstore' => { 'url' => 'https://petstore.swagger.io/v2/swagger.json' }
      },
      components: {
        'parameters' => { 'apiKey' => { 'name' => 'api_key', 'in' => 'header', 'value' => 'secret' } },
        'inputs' => { 'User' => { 'type' => 'object' } },
        'successActions' => { 'done' => { 'type' => 'end' } },
        'failureActions' => { 'retry' => { 'type' => 'retry' } }
      }
    }
  end

  def test_valid_and_all_eighteen_runtime_expression_roots
    ctx = sample_context

    refute Cdd::Arazzo::RuntimeExpression.valid?(nil)
    refute Cdd::Arazzo::RuntimeExpression.valid?('plain_string')
    refute Cdd::Arazzo::RuntimeExpression.valid?('Bearer {$invalid.root}')
    assert Cdd::Arazzo::RuntimeExpression.valid?('$statusCode')
    assert Cdd::Arazzo::RuntimeExpression.valid?('Bearer {$steps.loginStep.outputs.token}')

    assert_equal 123, Cdd::Arazzo::RuntimeExpression.evaluate(123, ctx)
    assert_equal 'literal', Cdd::Arazzo::RuntimeExpression.evaluate('literal', ctx)
    assert_equal [200, 'POST'], Cdd::Arazzo::RuntimeExpression.evaluate(['$statusCode', '$method'], ctx)
    assert_equal({ a: 'https://api.example.com/v1/pets' }, Cdd::Arazzo::RuntimeExpression.evaluate({ a: '$url' }, ctx))

    assert_equal 'https://api.example.com/v1/pets', Cdd::Arazzo::RuntimeExpression.evaluate('$url', ctx)
    assert_equal 'POST', Cdd::Arazzo::RuntimeExpression.evaluate('$method', ctx)
    assert_equal 200, Cdd::Arazzo::RuntimeExpression.evaluate('$statusCode', ctx)
    assert_equal 201, Cdd::Arazzo::RuntimeExpression.evaluate('$statusCode', { 'statusCode' => 201 })
    assert_equal 'https://api.example.com/arazzo.json', Cdd::Arazzo::RuntimeExpression.evaluate('$self', ctx)
    assert_equal 'urn:self', Cdd::Arazzo::RuntimeExpression.evaluate('$self', { '$self' => 'urn:self' })

    assert_equal 'Bearer req-tok', Cdd::Arazzo::RuntimeExpression.evaluate('$request.header.authorization', ctx)
    assert_equal 'val', Cdd::Arazzo::RuntimeExpression.evaluate('$request.header.x-custom', ctx)
    assert_equal 'active', Cdd::Arazzo::RuntimeExpression.evaluate('$request.query.filter', ctx)
    assert_equal '99', Cdd::Arazzo::RuntimeExpression.evaluate('$request.path.petId', ctx)
    assert_equal({ 'name' => 'Fluffy', 'tags' => %w[cute fast] },
                 Cdd::Arazzo::RuntimeExpression.evaluate('$request.body', ctx))
    assert_equal 'Fluffy', Cdd::Arazzo::RuntimeExpression.evaluate('$request.body#/name', ctx)
    assert_equal 'fast', Cdd::Arazzo::RuntimeExpression.evaluate('$request.body#/tags/1', ctx)
    assert_equal 'Fluffy', Cdd::Arazzo::RuntimeExpression.evaluate('$request.body.name', ctx)

    assert_equal 'application/json', Cdd::Arazzo::RuntimeExpression.evaluate('$response.header.content-type', ctx)
    assert_equal 42, Cdd::Arazzo::RuntimeExpression.evaluate('$response.body#/id', ctx)
    assert_equal 'B2', Cdd::Arazzo::RuntimeExpression.evaluate('$response.body#/items/1/code', ctx)

    assert_equal 'corr-123', Cdd::Arazzo::RuntimeExpression.evaluate('$message.header.correlationId', ctx)
    assert_equal true, Cdd::Arazzo::RuntimeExpression.evaluate('$message.payload#/nested/ok', ctx)

    assert_equal 'alice', Cdd::Arazzo::RuntimeExpression.evaluate('$inputs.username', ctx)
    assert_equal 42, Cdd::Arazzo::RuntimeExpression.evaluate('$outputs.finalId', ctx)
    assert_equal 'tok-xyz', Cdd::Arazzo::RuntimeExpression.evaluate('$steps.loginStep.outputs.token', ctx)
    assert_equal 'y', Cdd::Arazzo::RuntimeExpression.evaluate('$steps.loginStep.outputs.items.1', ctx)
    assert_equal 'y', Cdd::Arazzo::RuntimeExpression.evaluate('$steps.loginStep.outputs.items#/1', ctx)
    assert_equal 'jwt-999', Cdd::Arazzo::RuntimeExpression.evaluate('$workflows.authFlow.outputs.jwt', ctx)
    assert_equal 'https://petstore.swagger.io/v2/swagger.json',
                 Cdd::Arazzo::RuntimeExpression.evaluate('$sourceDescriptions.petstore.url', ctx)
    assert_equal 'secret', Cdd::Arazzo::RuntimeExpression.evaluate('$components.parameters.apiKey.value', ctx)
    assert_equal 'Bearer tok-xyz',
                 Cdd::Arazzo::RuntimeExpression.evaluate('Bearer {$steps.loginStep.outputs.token}', ctx)

    assert_raises(Cdd::RuntimeExpressionError) { Cdd::Arazzo::RuntimeExpression.evaluate('$unknown.foo', ctx) }
    assert_raises(Cdd::RuntimeExpressionError) { Cdd::Arazzo::RuntimeExpression.evaluate('$request.invalid.foo', ctx) }
  end

  def test_edge_cases_and_ruby_translation
    assert_nil Cdd::Arazzo::RuntimeExpression.lookup_case_insensitive(nil, 'a')
    assert_nil Cdd::Arazzo::RuntimeExpression.lookup_case_insensitive({ a: 1 }, 'missing')
    assert_nil Cdd::Arazzo::RuntimeExpression.fetch_ctx(nil, :a)
    assert_equal '{bad_json', Cdd::Arazzo::RuntimeExpression.parse_json_if_string('{bad_json')
    assert_equal({ a: 1 }, Cdd::Arazzo::RuntimeExpression.resolve_json_pointer({ a: 1 }, ''))
    assert_nil Cdd::Arazzo::RuntimeExpression.resolve_json_pointer({ a: 1 }, '/missing/deep')
    assert_nil Cdd::Arazzo::RuntimeExpression.resolve_json_pointer(123, '/a')
    assert_nil Cdd::Arazzo::RuntimeExpression.lookup_path({ a: nil }, 'a.b.c')
    assert_nil Cdd::Arazzo::RuntimeExpression.evaluate('$inputs.missing', {})
    assert_nil Cdd::Arazzo::RuntimeExpression.evaluate('$steps.missing', {})
    assert_nil Cdd::Arazzo::RuntimeExpression.evaluate('$request.header.missing', {})

    assert_equal '42', Cdd::Arazzo::RuntimeExpression.to_ruby_expr(42)
    assert_equal '"hello"', Cdd::Arazzo::RuntimeExpression.to_ruby_expr('hello')
    assert_equal 'status_code', Cdd::Arazzo::RuntimeExpression.to_ruby_expr('$statusCode')
    assert_equal 'request_url', Cdd::Arazzo::RuntimeExpression.to_ruby_expr('$url')
    assert_equal 'http_method', Cdd::Arazzo::RuntimeExpression.to_ruby_expr('$method')
    assert_equal 'self_uri', Cdd::Arazzo::RuntimeExpression.to_ruby_expr('$self')
    assert_equal 'inputs[:user]', Cdd::Arazzo::RuntimeExpression.to_ruby_expr('$inputs.user')
    assert_equal 'steps.dig("s1", :outputs, "tok")',
                 Cdd::Arazzo::RuntimeExpression.to_ruby_expr('$steps.s1.outputs.tok')
    assert_equal 'response_body["id"]', Cdd::Arazzo::RuntimeExpression.to_ruby_expr('$response.body#/id')
    assert_includes Cdd::Arazzo::RuntimeExpression.to_ruby_expr('Bearer {$inputs.tok}'), 'RuntimeExpression.evaluate'
    assert_includes Cdd::Arazzo::RuntimeExpression.to_ruby_expr('$workflows.wf1.outputs.out'),
                    'RuntimeExpression.evaluate'

    assert_equal '$statusCode', Cdd::Arazzo::RuntimeExpression.from_ruby_expr('status_code')
    assert_equal '$url', Cdd::Arazzo::RuntimeExpression.from_ruby_expr('request_url')
    assert_equal '$method', Cdd::Arazzo::RuntimeExpression.from_ruby_expr('http_method')
    assert_equal '$self', Cdd::Arazzo::RuntimeExpression.from_ruby_expr('self_uri')
    assert_equal '$inputs.user', Cdd::Arazzo::RuntimeExpression.from_ruby_expr('inputs[:user]')
    assert_equal '$steps.s1.outputs.tok',
                 Cdd::Arazzo::RuntimeExpression.from_ruby_expr('steps.dig("s1", :outputs, "tok")')
    assert_equal '$response.body#/id', Cdd::Arazzo::RuntimeExpression.from_ruby_expr('response_body["id"]')
    assert_equal '$workflows.w.outputs.x',
                 Cdd::Arazzo::RuntimeExpression.from_ruby_expr(
                   'Cdd::Arazzo::RuntimeExpression.evaluate("$workflows.w.outputs.x", context)'
                 )
    assert_equal 'plain', Cdd::Arazzo::RuntimeExpression.from_ruby_expr('"plain"')
  end

  def test_criterion_selector_and_payload_replacer
    ctx = sample_context

    assert Cdd::Arazzo::CriterionEvaluator.evaluate(
      { 'context' => '$statusCode', 'condition' => '$statusCode == 200 && $inputs.count >= 2', 'type' => 'simple' },
      ctx
    )
    assert Cdd::Arazzo::CriterionEvaluator.evaluate(
      { 'context' => '$statusCode', 'condition' => "'a || b' == 'a || b' && \"x && y\" == \"x && y\"", 'type' => 'simple' },
      ctx
    )
    assert Cdd::Arazzo::CriterionEvaluator.evaluate(
      { 'condition' => '$statusCode == 404 || $statusCode == 200', 'type' => 'simple' },
      ctx
    )
    assert Cdd::Arazzo::CriterionEvaluator.evaluate(
      { 'context' => '$response.body', 'condition' => '$.id > 10 && $.id < 100 && $.id <= 42 && $.id != 0' },
      ctx
    )
    assert Cdd::Arazzo::CriterionEvaluator.evaluate(
      { 'condition' => '1.5 < 2.5 && true == true && false == false && null == nil && raw == raw' },
      ctx
    )
    assert Cdd::Arazzo::CriterionEvaluator.values_match?('10.5', '>', '2')
    refute Cdd::Arazzo::CriterionEvaluator.values_match?('not_a_num', '<', 5)
    assert Cdd::Arazzo::CriterionEvaluator.evaluate({ 'condition' => '$inputs.username' }, ctx)
    assert Cdd::Arazzo::CriterionEvaluator.evaluate(
      Cdd::IR.build_criterion({ 'context' => '$url', 'condition' => '^https://api', 'type' => 'regex' }),
      ctx
    )
    assert Cdd::Arazzo::CriterionEvaluator.evaluate(
      {
        'context' => '$response.body',
        'condition' => '$.status == "available"',
        'type' => { 'type' => 'jsonpath', 'version' => 'rfc9535' }
      },
      ctx
    )
    assert Cdd::Arazzo::CriterionEvaluator.evaluate(
      {
        'context' => '$response.body#/items',
        'condition' => '$[?(@.code == "A1")]',
        'type' => 'jsonpath'
      },
      ctx
    )
    assert Cdd::Arazzo::CriterionEvaluator.evaluate(
      { 'context' => '$response.body', 'condition' => '$.id', 'type' => 'jsonpath' },
      ctx
    )
    assert Cdd::Arazzo::CriterionEvaluator.evaluate(
      { 'context' => '$response.body', 'condition' => '/id', 'type' => 'jsonpointer' },
      ctx
    )
    xml_ctx = { response: { body: '<order><status>shipped</status></order>' } }
    assert Cdd::Arazzo::CriterionEvaluator.evaluate(
      {
        'context' => '$response.body',
        'condition' => '//status',
        'type' => Cdd::IR::ExpressionType.new(type: 'xpath', version: 'xpath-31', extensions: {})
      },
      xml_ctx
    )
    assert_raises(Cdd::RuntimeExpressionError) do
      Cdd::Arazzo::CriterionEvaluator.evaluate({ 'condition' => 'x', 'type' => 'invalid_type' }, ctx)
    end

    assert_equal 'tok-xyz', Cdd::Arazzo::SelectorEvaluator.extract('$steps.loginStep.outputs.token', ctx)
    assert_equal 42, Cdd::Arazzo::SelectorEvaluator.extract(
      { 'context' => '$response.body', 'selector' => '/id', 'type' => 'jsonpointer' },
      ctx
    )
    assert_equal 'B2', Cdd::Arazzo::SelectorEvaluator.extract(
      Cdd::IR.build_output_value({ 'context' => '$response.body', 'selector' => '$.items[1].code', 'type' => 'jsonpath' }),
      ctx
    )
    assert_equal 42, Cdd::Arazzo::SelectorEvaluator.extract(
      { 'selector' => '$.outputs.finalId', 'type' => 'jsonpath' },
      ctx
    )
    assert_equal ctx, Cdd::Arazzo::SelectorEvaluator.query_jsonpath(ctx, '$')
    assert_nil Cdd::Arazzo::SelectorEvaluator.query_jsonpath({ a: nil }, '$.a.b')
    assert_empty Cdd::Arazzo::SelectorEvaluator.apply_jsonpath_filter('not_array', '@.a == 1')
    assert_equal 'shipped', Cdd::Arazzo::SelectorEvaluator.extract(
      { 'context' => '$response.body', 'selector' => '//status', 'type' => 'xpath' },
      xml_ctx
    )
    assert_equal 'xpath-31', Cdd::Arazzo::SelectorEvaluator.query_xpath('<a v="xpath-31"/>', '//a/@v')
    assert_nil Cdd::Arazzo::SelectorEvaluator.query_xpath('<a/>', '//missing')
    assert_nil Cdd::Arazzo::SelectorEvaluator.query_xpath('<unclosed', '//a')
    assert_equal 'v1', Cdd::Arazzo::SelectorEvaluator.extract(
      { 'context' => '$url', 'selector' => '/(v\d+)/', 'type' => 'regex' },
      ctx
    )
    assert_nil Cdd::Arazzo::SelectorEvaluator.extract(
      { 'context' => '$url', 'selector' => 'nomatch', 'type' => 'regex' },
      ctx
    )
    assert_raises(Cdd::RuntimeExpressionError) do
      Cdd::Arazzo::SelectorEvaluator.extract({ 'context' => '$url', 'selector' => 'x', 'type' => 'bad' }, ctx)
    end

    payload = { 'user' => { 'name' => 'old' }, 'items' => %w[a b] }
    assert_equal payload, Cdd::Arazzo::PayloadReplacer.apply(payload, nil, ctx)
    replaced = Cdd::Arazzo::PayloadReplacer.apply(
      payload,
      [
        { 'target' => '/user/name', 'value' => '$inputs.username', 'targetSelectorType' => 'jsonpointer' },
        Cdd::IR::PayloadReplacement.new(
          target: '/items/0',
          target_selector_type: 'jsonpointer',
          value: '$steps.loginStep.outputs.token',
          extensions: {}
        ),
        { 'target' => '$.newField.nested', 'value' => 99, 'targetSelectorType' => 'jsonpath' }
      ],
      ctx
    )
    assert_equal 'alice', replaced['user']['name']
    assert_equal 'tok-xyz', replaced['items'][0]
    assert_equal 99, replaced['newField']['nested']

    arr_payload = [{ 'k' => 'v' }]
    Cdd::Arazzo::PayloadReplacer.replace_json_pointer(arr_payload, '/0/k', 'updated')
    assert_equal 'updated', arr_payload[0]['k']
    assert_equal 'root_val', Cdd::Arazzo::PayloadReplacer.replace_json_pointer(arr_payload, '/', 'root_val')
    Cdd::Arazzo::PayloadReplacer.replace_json_pointer('not_collection', '/a/b', 'x')

    xml_replaced = Cdd::Arazzo::PayloadReplacer.apply(
      '<order><status>pending</status></order>',
      [{ 'target' => '//status', 'value' => 'done', 'targetSelectorType' => 'xpath' }],
      ctx
    )
    assert_includes xml_replaced, '<status>done</status>'

    assert_raises(Cdd::RuntimeExpressionError) do
      Cdd::Arazzo::PayloadReplacer.apply({}, [{ 'target' => '/a', 'value' => 1, 'targetSelectorType' => 'bad' }], ctx)
    end
  end
end
