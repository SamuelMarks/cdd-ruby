# frozen_string_literal: true

require 'json'
require_relative '../token_scanner'
require_relative 'runtime_expression'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for parsing, evaluating, and emitting Arazzo 1.1.0 workflow specifications.
  module Arazzo
    # Parser for extracting Arazzo 1.1.0 workflows, steps, and metadata from Ruby source tokens.
    class Parser
      # Parses Ripper tokens to populate `ir.arazzo_spec` and `ir.workflows`.
      #
      # @param tokens [Array<Array>] Ripper lexed token array
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.parse(tokens, ir)
        spec = ir.arazzo_spec
        current_wf = nil
        tokens.each do |tok|
          next unless tok[1] == :on_comment

          current_wf = parse_comment_line(tok[2].strip, spec, ir, current_wf)
        end

        infer_unannotated_workflows(tokens, ir) if spec['workflows'].empty?
        synthesize_default_source(ir) if spec['workflows'].any? && spec['sourceDescriptions'].empty?
      end

      # Parses a single `# @arazzo*` comment line and updates `spec` or `current_wf`.
      #
      # @param line [String] stripped comment line
      # @param spec [Hash] target Arazzo spec hash
      # @param ir [Cdd::IR] Intermediate Representation
      # @param current_wf [Hash, nil] active workflow hash
      # @return [Hash, nil] active workflow hash
      def self.parse_comment_line(line, spec, ir, current_wf)
        return current_wf unless line.start_with?('# @arazzo')

        if line =~ /\A#\s*@arazzo_workflow\s+(\S+)\z/
          wf_id = Regexp.last_match(1)
          spec['workflows'] ||= []
          existing = spec['workflows'].find { |w| w['workflowId'] == wf_id }
          return nil if existing

          wf = { 'workflowId' => wf_id, 'steps' => [] }
          spec['workflows'] << wf
          ir.workflows |= [wf_id]
          return wf
        end

        parse_root_tag(line, spec)
        apply_workflow_attribute_tag(line, current_wf) if current_wf
        current_wf
      end

      # Safely parses a JSON payload inside an `@arazzo*` docstring tag.
      #
      # @param raw_json [String] raw JSON string
      # @return [Object] parsed JSON value
      # @raise [Cdd::ParseError] when `raw_json` is not valid JSON
      def self.parse_json_tag(raw_json)
        JSON.parse(raw_json)
      rescue JSON::ParserError => e
        raise Cdd::ParseError, "Invalid JSON in Arazzo docstring tag: #{e.message}"
      end

      # Parses root-level `@arazzo*` tags (`@arazzo`, `@arazzo_self`, `@arazzo_info_*`, `@arazzo_source`, etc.).
      #
      # @param line [String] stripped comment line
      # @param spec [Hash] target Arazzo spec hash
      # @return [void]
      def self.parse_root_tag(line, spec)
        case line
        when /\A#\s*@arazzo\s+(\S+)\z/ then spec['arazzo'] = Regexp.last_match(1)
        when /\A#\s*@arazzo_self\s+(.+)\z/ then spec['$self'] = Regexp.last_match(1).strip
        when /\A#\s*@arazzo_info_(title|summary|description|version)\s+(.+)\z/
          spec['info'] ||= {}
          spec['info'][Regexp.last_match(1)] = Regexp.last_match(2).strip
        when /\A#\s*@arazzo_info_ext\s+(x-\S+)\s+(.+)\z/
          spec['info'] ||= {}
          spec['info'][Regexp.last_match(1)] = parse_json_tag(Regexp.last_match(2))
        when /\A#\s*@arazzo_ext\s+(x-\S+)\s+(.+)\z/
          spec[Regexp.last_match(1)] = parse_json_tag(Regexp.last_match(2))
        when /\A#\s*@arazzo_source\s+(.+)\z/
          spec['sourceDescriptions'] ||= []
          src_obj = parse_json_tag(Regexp.last_match(1))
          spec['sourceDescriptions'] |= [src_obj]
        when /\A#\s*@arazzo_components\s+(.+)\z/
          spec['components'] = parse_json_tag(Regexp.last_match(1))
        end
      end

      # Applies a workflow attribute or step JSON tag onto `current_wf`.
      #
      # @param line [String] stripped comment line
      # @param current_wf [Hash] active workflow hash
      # @return [void]
      def self.apply_workflow_attribute_tag(line, current_wf)
        case line
        when /\A#\s*@arazzo_summary\s+(.+)\z/ then current_wf['summary'] = Regexp.last_match(1).strip
        when /\A#\s*@arazzo_description\s+(.+)\z/ then current_wf['description'] = Regexp.last_match(1).strip
        when /\A#\s*@arazzo_inputs\s+(.+)\z/ then current_wf['inputs'] = parse_json_tag(Regexp.last_match(1))
        when /\A#\s*@arazzo_depends_on\s+(.+)\z/ then current_wf['dependsOn'] = parse_json_tag(Regexp.last_match(1))
        when /\A#\s*@arazzo_workflow_params\s+(.+)\z/
          current_wf['parameters'] = parse_json_tag(Regexp.last_match(1))
        when /\A#\s*@arazzo_workflow_success_actions\s+(.+)\z/
          current_wf['successActions'] = parse_json_tag(Regexp.last_match(1))
        when /\A#\s*@arazzo_workflow_failure_actions\s+(.+)\z/
          current_wf['failureActions'] = parse_json_tag(Regexp.last_match(1))
        when /\A#\s*@arazzo_workflow_outputs\s+(.+)\z/
          current_wf['outputs'] = parse_json_tag(Regexp.last_match(1))
        when /\A#\s*@arazzo_workflow_ext\s+(x-\S+)\s+(.+)\z/
          current_wf[Regexp.last_match(1)] = parse_json_tag(Regexp.last_match(2))
        when /\A#\s*@arazzo_step_json\s+(.+)\z/
          current_wf['steps'] << parse_json_tag(Regexp.last_match(1))
        end
      end

      # Infers workflows, steps, data-flow dependencies, and criteria from unannotated Ruby source tokens.
      #
      # @param tokens [Array<Array>] Ripper lexed token array
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.infer_unannotated_workflows(tokens, ir)
        source = tokens.map { |t| t[2] }.join
        return unless source.match?(/class\s+\w*(?:Workflow|Orchestrator)|def\s+(?:workflow_|test_\w*workflow)/)

        source.scan(/def\s+([a-zA-Z0-9_]+)(?:\(([^)]*)\))?(.*?)^\s*end/m) do |m_name, _args, body|
          next if m_name == 'initialize'

          steps = infer_steps_from_method_body(body)
          next if steps.empty?

          wf_id = m_name.sub(/\Atest_workflow_/, '').sub(/\Aworkflow_/, '')
          ir.arazzo_spec['workflows'] << { 'workflowId' => wf_id, 'steps' => steps }
          ir.workflows |= [wf_id]
        end
      end

      # Regex matching a client SDK or orchestrator method invocation in Ruby code.
      CLIENT_CALL_REGEX = /\A(?:(\w+)\s*=\s*)?(?:@?clients(?:\[.+?\]|\.values\.first)&?\.|client\.)(\w+)(?:\((.*)\))?/

      # Infers an ordered array of Arazzo `Step` hashes from a Ruby method body string.
      #
      # @param body [String] Ruby method body source
      # @return [Array<Hash>] inferred steps
      def self.infer_steps_from_method_body(body)
        steps = []
        var_to_step = {}
        body.each_line do |raw_line|
          line = raw_line.strip
          if line =~ CLIENT_CALL_REGEX
            step = build_inferred_client_step(Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3),
                                              steps.size + 1, var_to_step)
            steps << step
          elsif line =~ /\A(get|post|put|delete|patch)\s+['"]([^'"]+)['"]/
            op_path = "#{Regexp.last_match(1).upcase} #{Regexp.last_match(2)}"
            steps << { 'stepId' => "step_#{steps.size + 1}", 'operationPath' => op_path }
          elsif line =~ /assert_equal\s+(\d+),\s*(?:last_response\.status|status_code)/ && steps.any?
            steps.last['successCriteria'] ||= []
            steps.last['successCriteria'] << {
              'context' => '$statusCode',
              'condition' => "$statusCode == #{Regexp.last_match(1)}",
              'type' => 'simple'
            }
          end
        end
        steps
      end

      # Builds an inferred Arazzo `Step` hash from a client method call and tracks variable data-flow.
      #
      # @param assign_var [String, nil] local variable receiving the response
      # @param op_id [String] invoked operation method name
      # @param raw_args [String, nil] argument list snippet
      # @param index [Integer] 1-based step index
      # @param var_to_step [Hash{String => Hash}] map of variable names to prior step hashes
      # @return [Hash] inferred step hash
      def self.build_inferred_client_step(assign_var, op_id, raw_args, index, var_to_step)
        step_id = assign_var ? assign_var.sub(/_res\z/, '') : "step_#{index}"
        step = { 'stepId' => step_id, 'operationId' => op_id }
        params = infer_step_params(raw_args.to_s, var_to_step)
        step['parameters'] = params unless params.empty?
        var_to_step[assign_var] = step if assign_var
        step
      end

      # Infers step parameters and automatically links upstream step outputs when variables are referenced.
      #
      # @param args_str [String] raw argument snippet
      # @param var_to_step [Hash{String => Hash}] map of prior step result variables to step hashes
      # @return [Array<Hash>] inferred parameter list
      def self.infer_step_params(args_str, var_to_step)
        return [] if args_str.strip.empty?

        args_str.split(',').filter_map do |pair|
          next nil unless pair =~ /\A\s*([a-zA-Z0-9_]+):\s*(.+)\z/

          p_name = Regexp.last_match(1)
          rhs = Regexp.last_match(2).strip
          val = resolve_inferred_param_rhs(rhs, var_to_step)
          { 'name' => p_name, 'in' => 'query', 'value' => val }
        end
      end

      # Resolves a parameter right-hand side expression, synthesizing upstream step outputs if needed.
      #
      # @param rhs [String] Ruby argument value expression
      # @param var_to_step [Hash{String => Hash}] prior step variable map
      # @return [String] Arazzo runtime expression or literal value
      def self.resolve_inferred_param_rhs(rhs, var_to_step)
        if rhs =~ /\A(\w+)\[['"]([a-zA-Z0-9_]+)['"]\]\z/ && var_to_step.key?(Regexp.last_match(1))
          upstream = var_to_step[Regexp.last_match(1)]
          field = Regexp.last_match(2)
          upstream['outputs'] ||= {}
          upstream['outputs'][field] = "$response.body#/#{field}"
          "$steps.#{upstream['stepId']}.outputs.#{field}"
        else
          RuntimeExpression.from_ruby_expr(rhs)
        end
      end

      # Synthesizes a default `openapi` sourceDescription entry if none was declared.
      #
      # @param ir [Cdd::IR] Intermediate Representation
      # @return [void]
      def self.synthesize_default_source(ir)
        ir.arazzo_spec['sourceDescriptions'] << {
          'name' => 'default_api',
          'url' => './openapi.json',
          'type' => 'openapi'
        }
      end
    end
  end
end
