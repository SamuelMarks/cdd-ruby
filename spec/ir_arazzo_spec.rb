# frozen_string_literal: true

require_relative 'spec_helper'

class IrArazzoTest < Minitest::Test
  def sample_arazzo_spec
    {
      'arazzo' => '1.1.0',
      '$self' => 'https://example.com/arazzo.json',
      'x-root-ext' => 'root-val',
      'info' => {
        'title' => 'Petstore Workflows',
        'summary' => 'E2E Petstore Workflows',
        'description' => 'Orchestrates petstore operations',
        'version' => '1.1.0',
        'x-info-ext' => true
      },
      'sourceDescriptions' => [
        {
          'name' => 'petstore',
          'url' => './petstore_oas3.json',
          'type' => 'openapi',
          'x-source-ext' => 42
        }
      ],
      'workflows' => [
        {
          'workflowId' => 'loginAndBuyPet',
          'summary' => 'Login and purchase a pet',
          'description' => 'Full pet purchase lifecycle',
          'inputs' => {
            'type' => 'object',
            'properties' => { 'username' => { 'type' => 'string' } }
          },
          'dependsOn' => ['setupStore'],
          'parameters' => [
            { 'name' => 'X-Trace', 'in' => 'header', 'value' => '$inputs.username', 'x-param-ext' => 'p' },
            { 'reference' => '$components.parameters.sharedAuth', 'value' => 'override' }
          ],
          'steps' => [
            {
              'stepId' => 'loginStep',
              'description' => 'Authenticate user',
              'operationId' => 'loginUser',
              'operationPath' => '{$sourceDescriptions.petstore.url}#/paths/~1user~1login/get',
              'channelPath' => '/user/events',
              'workflowId' => nil,
              'timeout' => 5000,
              'correlationId' => '$message.header#/correlationId',
              'action' => 'send',
              'dependsOn' => ['initStep'],
              'x-step-ext' => 'step-val',
              'parameters' => [
                { 'name' => 'username', 'in' => 'query', 'value' => '$inputs.username' },
                { 'reference' => '$components.parameters.sharedAuth' }
              ],
              'requestBody' => {
                'contentType' => 'application/json',
                'payload' => { 'user' => 'placeholder' },
                'replacements' => [
                  {
                    'target' => '/user',
                    'targetSelectorType' => { 'type' => 'jsonpointer', 'version' => 'rfc6901' },
                    'value' => '$inputs.username',
                    'x-rep-ext' => 1
                  }
                ],
                'x-rb-ext' => 2
              },
              'successCriteria' => [
                {
                  'context' => '$statusCode',
                  'condition' => '$statusCode == 200',
                  'type' => 'simple',
                  'x-crit-ext' => 3
                },
                {
                  'context' => '$response.body',
                  'condition' => '$.token',
                  'type' => { 'type' => 'jsonpath', 'version' => 'rfc9535', 'x-expr-ext' => 4 }
                }
              ],
              'onSuccess' => [
                {
                  'name' => 'proceedToOrder',
                  'type' => 'goto',
                  'stepId' => 'orderStep',
                  'workflowId' => nil,
                  'parameters' => [{ 'name' => 'token', 'in' => 'header', 'value' => '$steps.loginStep.outputs.token' }],
                  'criteria' => [{ 'context' => '$statusCode', 'condition' => '$statusCode == 200', 'type' => 'simple' }],
                  'x-succ-ext' => 5
                },
                { 'reference' => '$components.successActions.logDone' }
              ],
              'onFailure' => [
                {
                  'name' => 'retryLogin',
                  'type' => 'retry',
                  'retryAfter' => 2,
                  'retryLimit' => 3,
                  'stepId' => 'loginStep',
                  'workflowId' => nil,
                  'parameters' => [{ 'name' => 'attempt', 'in' => 'query', 'value' => '1' }],
                  'criteria' => [{ 'context' => '$statusCode', 'condition' => '$statusCode == 503', 'type' => 'simple' }],
                  'x-fail-ext' => 6
                },
                { 'reference' => '$components.failureActions.abortFlow' }
              ],
              'outputs' => {
                'token' => '$response.body#/token',
                'selectedId' => {
                  'context' => '$response.body',
                  'selector' => '$.user.id',
                  'type' => { 'type' => 'jsonpath', 'version' => 'rfc9535' },
                  'x-sel-ext' => 7
                },
                'simpleSelect' => {
                  'context' => '$response.body',
                  'selector' => '/id',
                  'type' => 'jsonpointer'
                }
              }
            },
            {
              'stepId' => 'minimalStep',
              'operationId' => 'getInventory'
            }
          ],
          'successActions' => [
            { 'name' => 'finishAll', 'type' => 'end' }
          ],
          'failureActions' => [
            { 'name' => 'failAll', 'type' => 'end' }
          ],
          'outputs' => {
            'finalToken' => '$steps.loginStep.outputs.token'
          },
          'x-wf-ext' => 8
        }
      ],
      'components' => {
        'inputs' => { 'UserInput' => { 'type' => 'object' } },
        'parameters' => {
          'sharedAuth' => { 'name' => 'Authorization', 'in' => 'header', 'value' => 'Bearer token' }
        },
        'successActions' => {
          'logDone' => { 'name' => 'logDone', 'type' => 'end' }
        },
        'failureActions' => {
          'abortFlow' => { 'name' => 'abortFlow', 'type' => 'end' }
        },
        'x-comp-ext' => 9
      }
    }
  end

  def test_from_arazzo_hash_and_typed_arazzo
    spec = sample_arazzo_spec
    ir = Cdd::IR.from_arazzo_hash(spec)

    assert_equal ['loginAndBuyPet'], ir.workflows
    assert_equal spec, ir.to_arazzo_hash

    typed = ir.typed_arazzo
    assert_equal '1.1.0', typed.arazzo
    assert_equal 'https://example.com/arazzo.json', typed.self_uri
    assert_equal({ 'x-root-ext' => 'root-val' }, typed.extensions)
    assert_equal 'Petstore Workflows', typed.info.title
    assert_equal 'E2E Petstore Workflows', typed.info.summary
    assert_equal({ 'x-info-ext' => true }, typed.info.extensions)

    assert_equal 1, typed.source_descriptions.size
    assert_equal 'petstore', typed.source_descriptions[0].name
    assert_equal 'openapi', typed.source_descriptions[0].type

    wf = typed.workflows[0]
    assert_equal 'loginAndBuyPet', wf.workflow_id
    assert_equal ['setupStore'], wf.depends_on
    assert_equal 2, wf.parameters.size
    assert_instance_of Cdd::IR::ArazzoParameter, wf.parameters[0]
    assert_instance_of Cdd::IR::ReusableObject, wf.parameters[1]

    step = wf.steps[0]
    assert_equal 'loginStep', step.step_id
    assert_equal 5000, step.timeout
    assert_equal 'send', step.action
    assert_equal 'application/json', step.request_body.content_type
    assert_equal '/user', step.request_body.replacements[0].target
    assert_equal 'simple', step.success_criteria[0].type
    assert_instance_of Cdd::IR::ExpressionType, step.success_criteria[1].type
    assert_equal 'rfc9535', step.success_criteria[1].type.version

    assert_instance_of Cdd::IR::SuccessAction, step.on_success[0]
    assert_instance_of Cdd::IR::ReusableObject, step.on_success[1]
    assert_instance_of Cdd::IR::FailureAction, step.on_failure[0]
    assert_equal 2, step.on_failure[0].retry_after
    assert_equal 3, step.on_failure[0].retry_limit
    assert_instance_of Cdd::IR::ReusableObject, step.on_failure[1]

    assert_equal '$response.body#/token', step.outputs['token']
    assert_instance_of Cdd::IR::Selector, step.outputs['selectedId']
    assert_instance_of Cdd::IR::ExpressionType, step.outputs['selectedId'].type
    assert_equal 'jsonpointer', step.outputs['simpleSelect'].type

    min_step = wf.steps[1]
    assert_nil min_step.request_body
    assert_empty min_step.parameters

    assert_equal({ 'type' => 'object' }, typed.components.inputs['UserInput'])
    assert_equal 'Authorization', typed.components.parameters['sharedAuth'].name
    assert_equal 'end', typed.components.success_actions['logDone'].type
    assert_equal 'end', typed.components.failure_actions['abortFlow'].type
  end

  def test_arazzo_validation_and_defaults
    assert_raises(Cdd::ArazzoValidationError) { Cdd::IR.from_arazzo_hash(nil) }
    assert_raises(Cdd::ArazzoValidationError) { Cdd::IR.from_arazzo_hash({ 'arazzo' => '2.0.0' }) }

    ir_one_zero = Cdd::IR.from_arazzo_hash({ 'arazzo' => '1.0.1', 'workflows' => ['not_a_hash'] })
    assert_empty ir_one_zero.workflows

    ir_no_wf = Cdd::IR.from_arazzo_hash({ 'arazzo' => '1.1.0' })
    assert_empty ir_no_wf.workflows

    empty_ir = Cdd::IR.new(nil, {})
    typed_empty = empty_ir.typed_arazzo
    assert_equal '1.1.0', typed_empty.arazzo
    assert_equal 'Generated Workflows', typed_empty.info.title
    assert_equal '0.0.4', typed_empty.info.version
    assert_nil typed_empty.components
    assert_empty Cdd::IR.extract_extensions(nil)

    empty_comp = Cdd::IR.build_arazzo_components({})
    assert_empty empty_comp.inputs
    assert_empty empty_comp.parameters

    empty_rb = Cdd::IR.build_arazzo_request_body({})
    assert_empty empty_rb.replacements

    min_wf = Cdd::IR.build_workflow({ 'workflowId' => 'min' })
    assert_empty min_wf.steps
    assert_empty min_wf.outputs

    err = Cdd::RuntimeExpressionError.new('bad expression')
    assert_kind_of Cdd::Error, err
  end
end
