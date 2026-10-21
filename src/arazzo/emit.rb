# frozen_string_literal: true

require 'json'
require_relative 'runtime_expression'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for parsing, evaluating, and emitting Arazzo 1.1.0 workflow specifications.
  module Arazzo
    # Emitter for generating Ruby workflow orchestrator code and `@arazzo_*` YARD tags from `Cdd::IR`.
    class Emitter
      # Emits a complete Ruby workflow orchestrator file with full `@arazzo_*` annotations from `ir`.
      #
      # @param ir [Cdd::IR] Intermediate Representation containing `arazzo_spec`
      # @return [String] generated Ruby code
      def self.emit(ir)
        spec = ir.arazzo_spec
        return '' unless spec.is_a?(Hash) && (spec['workflows']&.any? || spec['sourceDescriptions']&.any?)

        lines = emit_root_lines(ir)
        lines.concat(emit_source_lines(spec['sourceDescriptions'] || []))
        lines.concat(emit_component_lines(spec['components']))
        lines.push(
          'class WorkflowsOrchestrator',
          '  attr_reader :clients, :context',
          '',
          '  def initialize(clients = {}, context = {})',
          '    @clients = clients',
          '    @context = context',
          '  end'
        )
        (spec['workflows'] || []).each { |workflow| lines.concat(emit_workflow_lines(workflow)) }
        lines << 'end'
        "#{lines.join("\n")}\n"
      end

      # Emits root-level `@arazzo` metadata and vendor extension lines.
      #
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [Array<String>] YARD header comment lines
      def self.emit_root_lines(ir)
        typed = ir.typed_arazzo
        spec = ir.arazzo_spec
        lines = ["# @arazzo #{typed.arazzo}"]
        lines << "# @arazzo_self #{typed.self_uri}" if typed.self_uri
        lines.concat(emit_info_lines(typed.info, spec['info'] || {}))
        lines.concat(emit_extension_lines('@arazzo_ext', typed.extensions))
      end

      # Emits `@arazzo_info_*` tag lines from the `info` object.
      #
      # @param typed_info [Cdd::IR::ArazzoInfo] typed Arazzo info object
      # @param raw_info [Hash] raw Arazzo info hash
      # @return [Array<String>] YARD comment lines
      def self.emit_info_lines(typed_info, raw_info)
        lines = []
        lines << "# @arazzo_info_title #{typed_info.title}" if raw_info['title']
        lines << "# @arazzo_info_summary #{typed_info.summary}" if typed_info.summary
        lines << "# @arazzo_info_description #{typed_info.description}" if typed_info.description
        lines << "# @arazzo_info_version #{typed_info.version}" if raw_info['version']
        lines.concat(emit_extension_lines('@arazzo_info_ext', typed_info.extensions))
      end

      # Emits `@arazzo_source` tag lines for all `sourceDescriptions`.
      #
      # @param sources [Array<Hash>] source description entries
      # @return [Array<String>] YARD comment lines
      def self.emit_source_lines(sources)
        sources.map { |src| "# @arazzo_source #{JSON.generate(src)}" }
      end

      # Emits `@arazzo_components` tag line if reusable components are present.
      #
      # @param components [Hash, nil] Arazzo components object
      # @return [Array<String>] YARD comment lines
      def self.emit_component_lines(components)
        return [] unless components.is_a?(Hash) && !components.empty?

        ["# @arazzo_components #{JSON.generate(components)}"]
      end

      # Emits `^x-` vendor extension lines using `tag_name`.
      #
      # @param tag_name [String] YARD tag prefix
      # @param obj [Hash] source hash
      # @param indent [String] comment prefix indentation
      # @return [Array<String>] YARD extension lines
      def self.emit_extension_lines(tag_name, obj, indent = '')
        obj.each_with_object([]) do |(k, v), acc|
          acc << "#{indent}# #{tag_name} #{k} #{JSON.generate(v)}" if k.to_s.start_with?('x-')
        end
      end

      # Emits a single workflow method inside `WorkflowsOrchestrator`.
      #
      # @param workflow [Hash] raw workflow object
      # @return [Array<String>] Ruby method lines with YARD tags
      def self.emit_workflow_lines(workflow)
        wf_id = workflow['workflowId']
        lines = ['']
        lines.concat(emit_workflow_tag_lines(workflow))
        lines << "  def #{wf_id}(inputs = {})"
        lines << '    steps = {}'
        (workflow['dependsOn'] || []).each { |dep| lines << "    #{dep}(inputs)" }
        (workflow['steps'] || []).each { |step| lines.concat(emit_step_lines(step)) }
        lines << emit_workflow_return_line(workflow['outputs'] || {})
        lines << '  end'
      end

      # Emits YARD tag lines describing a `Workflow` object.
      #
      # @param workflow [Hash] raw workflow object
      # @return [Array<String>] indented YARD comment lines
      def self.emit_workflow_tag_lines(workflow)
        lines = ["  # @arazzo_workflow #{workflow['workflowId']}"]
        lines << "  # @arazzo_summary #{workflow['summary']}" if workflow['summary']
        lines << "  # @arazzo_description #{workflow['description']}" if workflow['description']
        lines << "  # @arazzo_inputs #{JSON.generate(workflow['inputs'])}" if workflow['inputs']
        lines << "  # @arazzo_depends_on #{JSON.generate(workflow['dependsOn'])}" if workflow['dependsOn']
        lines << "  # @arazzo_workflow_params #{JSON.generate(workflow['parameters'])}" if workflow['parameters']
        if workflow['successActions']
          lines << "  # @arazzo_workflow_success_actions #{JSON.generate(workflow['successActions'])}"
        end
        if workflow['failureActions']
          lines << "  # @arazzo_workflow_failure_actions #{JSON.generate(workflow['failureActions'])}"
        end
        lines << "  # @arazzo_workflow_outputs #{JSON.generate(workflow['outputs'])}" if workflow['outputs']
        lines.concat(emit_extension_lines('@arazzo_workflow_ext', workflow, '  '))
      end

      # Emits the YARD tag and executable Ruby code lines for a single `Step` object.
      #
      # @param step [Hash] raw step object
      # @return [Array<String>] indented step execution lines
      def self.emit_step_lines(step)
        s_id = step['stepId']
        lines = [
          "    # @arazzo_step_json #{JSON.generate(step)}",
          "    #{s_id}_res = #{build_step_call_expr(step)}",
          "    steps[#{s_id.inspect}] = { response: #{s_id}_res, outputs: {} }"
        ]
        (step['outputs'] || []).each do |out_key, out_val|
          ext = format_output_extraction(s_id, out_val)
          lines << "    steps[#{s_id.inspect}][:outputs][#{out_key.inspect}] = #{ext}"
        end
        lines
      end

      # Builds the Ruby invocation expression for a `Step`.
      #
      # @param step [Hash] raw step object
      # @return [String] Ruby method call string
      def self.build_step_call_expr(step)
        args = build_step_call_args(step)
        args_str = args.empty? ? '' : "(#{args.join(', ')})"
        if step['workflowId']
          "#{step['workflowId']}#{args_str}"
        elsif step['operationId']
          "@clients.values.first&.#{step['operationId']}#{args_str}"
        elsif step['channelPath']
          call_args = ([step['channelPath'].inspect] + args).join(', ')
          "@clients.values.first&.publish(#{call_args})"
        else
          call_args = ([step['operationPath'].to_s.inspect] + args).join(', ')
          "@clients.values.first&.request(#{call_args})"
        end
      end

      # Builds Ruby keyword arguments for a `Step` call from its `parameters` and `requestBody`.
      #
      # @param step [Hash] raw step object
      # @return [Array<String>] formatted argument strings
      def self.build_step_call_args(step)
        args = (step['parameters'] || []).filter_map do |param|
          next nil if param['reference']

          "#{param['name']}: #{RuntimeExpression.to_ruby_expr(param['value'])}"
        end
        rb = step['requestBody']
        args << "body: #{rb['payload'].inspect}" if rb.is_a?(Hash) && rb.key?('payload')
        args
      end

      # Formats the Ruby expression for extracting a step output.
      #
      # @param step_id [String] step identifier
      # @param out_val [String, Hash] output runtime expression or selector hash
      # @return [String] Ruby extraction snippet
      def self.format_output_extraction(step_id, out_val)
        if out_val.is_a?(String) && out_val =~ %r{\A\$response\.body#/([a-zA-Z0-9_]+)\z}
          "#{step_id}_res[#{Regexp.last_match(1).inspect}]"
        else
          ctx_str = "{ response: { body: #{step_id}_res }, steps: steps, inputs: inputs }"
          "Cdd::Arazzo::SelectorEvaluator.extract(#{out_val.inspect}, #{ctx_str})"
        end
      end

      # Emits the final return line for a workflow method from `outputs`.
      #
      # @param outputs [Hash] workflow outputs map
      # @return [String] return expression line
      def self.emit_workflow_return_line(outputs)
        return '    steps' if outputs.empty?

        pairs = outputs.map do |k, v|
          expr = if v.is_a?(String)
                   RuntimeExpression.to_ruby_expr(v)
                 else
                   "Cdd::Arazzo::SelectorEvaluator.extract(#{v.inspect}, { steps: steps, inputs: inputs })"
                 end
          "#{k.inspect} => #{expr}"
        end
        "    { #{pairs.join(', ')} }"
      end
    end
  end
end
