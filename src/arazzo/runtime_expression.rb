# frozen_string_literal: true

require 'json'
require_relative '../error'
require_relative '../ir'

# Core namespace for the CDD Ruby compiler and OpenAPI toolchain.
module Cdd
  # Module for parsing, evaluating, and emitting Arazzo 1.1.0 workflow specifications.
  module Arazzo
    # Parser, validator, evaluator, and Ruby AST translator for Arazzo 1.1.0 Runtime Expressions.
    class RuntimeExpression
      # Valid top-level Arazzo 1.1.0 runtime expression prefixes.
      VALID_ROOTS = %w[
        $url $method $statusCode $request. $response. $message.
        $inputs. $outputs. $steps. $workflows. $sourceDescriptions.
        $components. $self
      ].freeze

      # Validates whether `expr` is a valid Arazzo 1.1.0 runtime expression or interpolated template.
      #
      # @param expr [Object] candidate expression string
      # @return [Boolean] true if valid runtime expression or template containing valid expressions
      def self.valid?(expr)
        return false unless expr.is_a?(String)
        return true if VALID_ROOTS.any? { |r| expr == r || expr.start_with?(r) }

        embedded = expr.scan(/\{(\$[^}]+)\}/).flatten
        !embedded.empty? && embedded.all? { |inner| VALID_ROOTS.any? { |r| inner == r || inner.start_with?(r) } }
      end

      # Evaluates a runtime expression or interpolated string against a workflow execution `context`.
      #
      # @param expr [Object] expression string, literal, or Hash/Array template
      # @param context [Hash{Symbol, String => Object}] runtime execution state
      # @return [Object] evaluated value
      # @raise [Cdd::RuntimeExpressionError] when an invalid `$` expression is encountered
      def self.evaluate(expr, context = {})
        return evaluate_collection(expr, context) if expr.is_a?(Hash) || expr.is_a?(Array)
        return expr unless expr.is_a?(String)
        return expr.gsub(/\{(\$[^}]+)\}/) { evaluate_single(Regexp.last_match(1), context).to_s } if expr.include?('{$')
        return evaluate_single(expr, context) if expr.start_with?('$')

        expr
      end

      # Evaluates a Hash or Array recursively against `context`.
      #
      # @param collection [Hash, Array] nested data structure
      # @param context [Hash] runtime state
      # @return [Hash, Array] evaluated structure
      def self.evaluate_collection(collection, context)
        if collection.is_a?(Array)
          collection.map { |item| evaluate(item, context) }
        else
          collection.transform_values { |val| evaluate(val, context) }
        end
      end

      # Evaluates a single `$`-prefixed Arazzo 1.1.0 runtime expression against `context`.
      #
      # @param expr [String] runtime expression starting with `$`
      # @param context [Hash] runtime state
      # @return [Object] resolved value
      # @raise [Cdd::RuntimeExpressionError] when the expression root is unknown
      def self.evaluate_single(expr, context)
        case expr
        when '$url' then fetch_ctx(context, :url)
        when '$method' then fetch_ctx(context, :method)
        when '$statusCode' then fetch_ctx(context, :status_code) || fetch_ctx(context, :statusCode)
        when '$self' then fetch_ctx(context, :self_uri) || fetch_ctx(context, :$self)
        when /\A\$(request|response|message)\./ then evaluate_envelope(expr, context)
        when /\A\$(inputs|outputs)\.(.+)\z/
          lookup_path(fetch_ctx(context, Regexp.last_match(1).to_sym) || {}, Regexp.last_match(2))
        when /\A\$(steps|workflows|sourceDescriptions|components)\.(.+)\z/
          evaluate_namespace(Regexp.last_match(1), Regexp.last_match(2), context)
        else
          raise Cdd::RuntimeExpressionError, "Unsupported runtime expression: #{expr}"
        end
      end

      # Evaluates `$request.*`, `$response.*`, and `$message.*` expressions.
      #
      # @param expr [String] envelope runtime expression
      # @param context [Hash] runtime state
      # @return [Object] resolved value
      # @raise [Cdd::RuntimeExpressionError] when the sub-property is invalid
      def self.evaluate_envelope(expr, context)
        env_key, rest = expr.sub(/\A\$/, '').split('.', 2)
        env = fetch_ctx(context, env_key.to_sym) || {}
        if rest.start_with?('header.', 'query.', 'path.')
          kind, name = rest.split('.', 2)
          sub = fetch_ctx(env, kind.to_sym) || fetch_ctx(env, :"#{kind}s") || {}
          lookup_case_insensitive(sub, name)
        elsif rest.start_with?('body', 'payload')
          evaluate_body_or_payload(env, rest)
        else
          raise Cdd::RuntimeExpressionError, "Invalid envelope expression: #{expr}"
        end
      end

      # Evaluates `body` or `payload` with optional `#<json-pointer>` or `.property` suffix.
      #
      # @param env [Hash] request, response, or message envelope hash
      # @param rest [String] `body...` or `payload...` expression suffix
      # @return [Object] extracted body/payload field
      def self.evaluate_body_or_payload(env, rest)
        field = rest.start_with?('payload') ? :payload : :body
        data = fetch_ctx(env, field)
        data = parse_json_if_string(data)
        if rest.include?('#')
          _, pointer = rest.split('#', 2)
          resolve_json_pointer(data, pointer)
        elsif rest.include?('.')
          _, dotted = rest.split('.', 2)
          lookup_path(data, dotted)
        else
          data
        end
      end

      # Evaluates `$steps.*`, `$workflows.*`, `$sourceDescriptions.*`, and `$components.*` expressions.
      #
      # @param namespace [String] top-level namespace name
      # @param rest [String] dot/pointer path after namespace
      # @param context [Hash] runtime state
      # @return [Object] resolved value
      def self.evaluate_namespace(namespace, rest, context)
        ns_sym = namespace == 'sourceDescriptions' ? :source_descriptions : namespace.to_sym
        root = fetch_ctx(context, ns_sym) || fetch_ctx(context, namespace.to_sym) || {}
        lookup_path(root, rest)
      end

      # Resolves a dotted or `#`-pointer path against a nested Hash or Array.
      #
      # @param target [Object] root collection
      # @param path_str [String] dotted path with optional `#/pointer`
      # @return [Object] resolved element or nil
      def self.lookup_path(target, path_str)
        base_path, pointer = path_str.split('#', 2)
        current = base_path.split('.').reduce(target) do |acc, seg|
          break nil if acc.nil?

          acc = parse_json_if_string(acc)
          acc.is_a?(Array) && seg.match?(/\A\d+\z/) ? acc[seg.to_i] : fetch_ctx(acc, seg.to_sym)
        end
        pointer ? resolve_json_pointer(parse_json_if_string(current), pointer) : current
      end

      # Resolves an RFC 6901 JSON Pointer (`/a/b/0`) against `data`.
      #
      # @param data [Object] parsed JSON target
      # @param pointer [String] RFC 6901 pointer string
      # @return [Object] resolved value or nil
      def self.resolve_json_pointer(data, pointer)
        return data if pointer.nil? || pointer.empty? || pointer == '/'

        segments = pointer.sub(%r{\A/}, '').split('/').map { |s| s.gsub('~1', '/').gsub('~0', '~') }
        segments.reduce(data) do |acc, seg|
          break nil if acc.nil?

          acc = parse_json_if_string(acc)
          if acc.is_a?(Array) && seg.match?(/\A\d+\z/)
            acc[seg.to_i]
          elsif acc.is_a?(Hash)
            fetch_ctx(acc, seg.to_sym)
          end
        end
      end

      # Performs a case-insensitive key lookup on a Hash (used for HTTP headers).
      #
      # @param hash [Hash] source map
      # @param key [String] target key
      # @return [Object, nil] matched value
      def self.lookup_case_insensitive(hash, key)
        return nil unless hash.is_a?(Hash)

        direct = fetch_ctx(hash, key.to_sym)
        return direct unless direct.nil?

        pair = hash.find { |k, _| k.to_s.casecmp?(key.to_s) }
        pair ? pair[1] : nil
      end

      # Fetches a symbol or string key from `hash`.
      #
      # @param hash [Object] target hash
      # @param sym [Symbol] key symbol
      # @return [Object, nil] value
      def self.fetch_ctx(hash, sym)
        return nil unless hash.is_a?(Hash)

        hash.key?(sym) ? hash[sym] : hash[sym.to_s]
      end

      # Parses `val` as JSON if it is a JSON-formatted String.
      #
      # @param val [Object] value to inspect
      # @return [Object] parsed JSON or original value
      def self.parse_json_if_string(val)
        return val unless val.is_a?(String) && (val.start_with?('{') || val.start_with?('['))

        JSON.parse(val)
      rescue JSON::ParserError
        val
      end

      # Translates an Arazzo 1.1.0 runtime expression into an idiomatic Ruby code expression string.
      #
      # @param expr [Object] Arazzo runtime expression or literal
      # @return [String] Ruby source code expression
      def self.to_ruby_expr(expr)
        return expr.inspect unless expr.is_a?(String)
        return "Cdd::Arazzo::RuntimeExpression.evaluate(#{expr.inspect}, context)" if expr.include?('{$')
        return expr.inspect unless expr.start_with?('$')

        translate_direct_ruby_expr(expr)
      end

      # Translates a direct `$`-prefixed expression into idiomatic Ruby state access code.
      #
      # @param expr [String] `$` runtime expression
      # @return [String] Ruby source code expression
      def self.translate_direct_ruby_expr(expr)
        case expr
        when '$statusCode' then 'status_code'
        when '$url' then 'request_url'
        when '$method' then 'http_method'
        when '$self' then 'self_uri'
        when /\A\$inputs\.([a-zA-Z0-9_]+)\z/ then "inputs[#{Regexp.last_match(1).to_sym.inspect}]"
        when /\A\$steps\.([a-zA-Z0-9_-]+)\.outputs\.([a-zA-Z0-9_]+)\z/
          "steps.dig(#{Regexp.last_match(1).inspect}, :outputs, #{Regexp.last_match(2).inspect})"
        when %r{\A\$response\.body#/([a-zA-Z0-9_]+)\z}
          "response_body[#{Regexp.last_match(1).inspect}]"
        else
          "Cdd::Arazzo::RuntimeExpression.evaluate(#{expr.inspect}, context)"
        end
      end

      # Reverse-parses a Ruby code expression string back into an Arazzo 1.1.0 runtime expression.
      #
      # @param ruby_code [String] Ruby expression snippet
      # @return [String] canonical Arazzo runtime expression or literal
      def self.from_ruby_expr(ruby_code)
        code = ruby_code.to_s.strip
        case code
        when 'status_code', 'last_response.status', 'response.code.to_i' then '$statusCode'
        when 'request_url' then '$url'
        when 'http_method' then '$method'
        when 'self_uri' then '$self'
        when /\Ainputs\[:([a-zA-Z0-9_]+)\]\z/, /\Ainputs\['([a-zA-Z0-9_]+)'\]\z/
          "$inputs.#{Regexp.last_match(1)}"
        when /\Asteps\.dig\(['"]([a-zA-Z0-9_-]+)['"],\s*:outputs,\s*['"]([a-zA-Z0-9_]+)['"]\)\z/
          "$steps.#{Regexp.last_match(1)}.outputs.#{Regexp.last_match(2)}"
        when /\Aresponse_body\[['"]([a-zA-Z0-9_]+)['"]\]\z/
          "$response.body#/#{Regexp.last_match(1)}"
        when /\ACdd::Arazzo::RuntimeExpression\.evaluate\(['"]([^'"]+)['"]/
          Regexp.last_match(1)
        else
          code.gsub(/\A['"]|['"]\z/, '')
        end
      end
    end

    # Evaluates Arazzo 1.1.0 `Criterion` objects (`simple`, `regex`, `jsonpath`, `xpath`, `jsonpointer`).
    class CriterionEvaluator
      # Evaluates a `Criterion` (or raw criterion Hash) against `context`.
      #
      # @param criterion [Cdd::IR::Criterion, Hash] criterion specification
      # @param context [Hash] runtime state context
      # @return [Boolean] true if criterion passes
      # @raise [Cdd::RuntimeExpressionError] when an unknown criterion type is specified
      def self.evaluate(criterion, context = {})
        crit = criterion.is_a?(Cdd::IR::Criterion) ? criterion : Cdd::IR.build_criterion(criterion)
        type_name, version = extract_type_and_version(crit.type)
        target_val = crit.context ? RuntimeExpression.evaluate(crit.context, context) : context

        case type_name
        when nil, 'simple' then evaluate_simple(crit.condition.to_s, target_val, context)
        when 'regex' then Regexp.new(crit.condition.to_s).match?(target_val.to_s)
        when 'jsonpath' then jsonpath_criterion_match?(crit.condition.to_s, target_val, version)
        when 'xpath' then xpath_criterion_match?(crit.condition.to_s, target_val, version)
        when 'jsonpointer' then !RuntimeExpression.resolve_json_pointer(target_val, crit.condition.to_s).nil?
        else
          raise Cdd::RuntimeExpressionError, "Unsupported criterion type: #{type_name}"
        end
      end

      # Extracts the normalized type string and optional version string from `type_spec`.
      #
      # @param type_spec [String, Cdd::IR::ExpressionType, nil] criterion or selector type
      # @return [Array<String, nil>] `[type_name, version]`
      def self.extract_type_and_version(type_spec)
        if type_spec.is_a?(Cdd::IR::ExpressionType)
          [type_spec.type, type_spec.version]
        else
          [type_spec&.to_s, nil]
        end
      end

      # Evaluates a `simple` criterion condition (supporting `&&`, `||`, and comparison operators).
      #
      # @param condition [String] simple condition string
      # @param target_val [Object] resolved context value
      # @param context [Hash] full runtime context
      # @return [Boolean] evaluation result
      def self.evaluate_simple(condition, target_val, context)
        or_parts = split_outside_quotes(condition, '||')
        return or_parts.any? { |part| evaluate_simple(part.strip, target_val, context) } if or_parts.size > 1

        and_parts = split_outside_quotes(condition, '&&')
        return and_parts.all? { |part| evaluate_simple(part.strip, target_val, context) } if and_parts.size > 1

        if condition =~ /\A(.+?)\s*(==|!=|<=|>=|<|>)\s*(.+)\z/
          lhs = resolve_operand(Regexp.last_match(1).strip, target_val, context)
          op = Regexp.last_match(2)
          rhs = resolve_operand(Regexp.last_match(3).strip, target_val, context)
          values_match?(lhs, op, rhs)
        else
          val = resolve_operand(condition.strip, target_val, context)
          !val.nil? && val != false && val != ''
        end
      end

      # Splits a condition expression on `delimiter` (`'||'` or `'&&'`) while ignoring quoted string literals.
      #
      # @param str [String] condition expression
      # @param delimiter [String] two-character operator delimiter
      # @return [Array<String>] split segments
      def self.split_outside_quotes(str, delimiter)
        parts = []
        current = +''
        quote = nil
        idx = 0
        while idx < str.length
          ch = str[idx]
          if quote
            quote = nil if ch == quote
            current << ch
            idx += 1
          elsif ["'", '"'].include?(ch)
            quote = ch
            current << ch
            idx += 1
          elsif str[idx, delimiter.length] == delimiter
            parts << current
            current = +''
            idx += delimiter.length
          else
            current << ch
            idx += 1
          end
        end
        parts << current
      end

      # Resolves an operand in a simple condition (either `$` expression, JSONPath `$.*`, or literal).
      #
      # @param token [String] operand string
      # @param target_val [Object] current criterion context value
      # @param context [Hash] full runtime context
      # @return [Object] resolved operand value
      def self.resolve_operand(token, target_val, context)
        if token.start_with?('$.')
          SelectorEvaluator.query_jsonpath(target_val, token)
        elsif token.start_with?('$')
          RuntimeExpression.evaluate(token, context)
        elsif token =~ /\A['"](.*)['"]\z/
          Regexp.last_match(1)
        elsif token =~ /\A-?\d+\z/
          token.to_i
        elsif token =~ /\A-?\d+\.\d+\z/
          token.to_f
        elsif token == 'true' then true
        elsif token == 'false' then false
        elsif %w[null nil].include?(token) then nil
        else
          token
        end
      end

      # Compares `lhs` and `rhs` using operator `op`.
      #
      # @param lhs [Object] left operand
      # @param op [String] comparison operator
      # @param rhs [Object] right operand
      # @return [Boolean] comparison result
      def self.values_match?(lhs, op, rhs)
        case op
        when '==' then lhs == rhs || lhs.to_s == rhs.to_s
        when '!=' then lhs != rhs && lhs.to_s != rhs.to_s
        else
          l_num = numeric_operand(lhs)
          r_num = numeric_operand(rhs)
          return false unless l_num && r_num

          l_num.public_send(op.to_sym, r_num)
        end
      end

      # Converts a numeric value or numeric string into a `Float`, returning `nil` for non-numeric inputs.
      #
      # @param val [Object] raw operand value
      # @return [Float, nil] numeric value or nil
      def self.numeric_operand(val)
        return val.to_f if val.is_a?(Numeric)
        return val.to_f if val.is_a?(String) && val.strip =~ /\A-?\d+(?:\.\d+)?\z/

        nil
      end

      # Evaluates a `jsonpath` criterion condition (including filter expressions like `$[?(@.id == 1)]`).
      #
      # @param condition [String] JSONPath query or comparison
      # @param target_val [Object] JSON document target
      # @param _version [String, nil] JSONPath specification version (`rfc9535` or draft-goessner)
      # @return [Boolean] true if query matches a non-nil/non-empty result
      def self.jsonpath_criterion_match?(condition, target_val, _version = nil)
        if condition =~ /\A(\$\.[a-zA-Z0-9_.\[\]]+)\s*(==|!=|<=|>=|<|>)\s*(.+)\z/
          extracted = SelectorEvaluator.query_jsonpath(target_val, Regexp.last_match(1))
          rhs = resolve_operand(Regexp.last_match(3).strip, target_val, {})
          return values_match?(extracted, Regexp.last_match(2), rhs)
        end
        res = SelectorEvaluator.query_jsonpath(target_val, condition)
        res.is_a?(Array) ? !res.empty? : !res.nil? && res != false
      end

      # Evaluates an `xpath` criterion condition against an XML string.
      #
      # @param condition [String] XPath expression
      # @param target_val [Object] XML document string
      # @param _version [String, nil] XPath version (`xpath-31`, `xpath-20`, `xpath-10`)
      # @return [Boolean] true if XPath matches
      def self.xpath_criterion_match?(condition, target_val, _version = nil)
        res = SelectorEvaluator.query_xpath(target_val.to_s, condition)
        !res.nil? && res != '' && res != false
      end
    end

    # Evaluates Arazzo 1.1.0 `Selector` objects (`jsonpointer`, `jsonpath`, `xpath`, `regex`) for output extraction.
    class SelectorEvaluator
      # Extracts a value from `context` using a `Selector` object or runtime expression string.
      #
      # @param selector_or_expr [Cdd::IR::Selector, Hash, String] selector definition or runtime expression
      # @param context [Hash] runtime state context
      # @return [Object] extracted output value
      # @raise [Cdd::RuntimeExpressionError] when an unsupported selector type is provided
      def self.extract(selector_or_expr, context = {})
        return RuntimeExpression.evaluate(selector_or_expr, context) if selector_or_expr.is_a?(String)

        sel = if selector_or_expr.is_a?(Cdd::IR::Selector)
                selector_or_expr
              else
                Cdd::IR.build_output_value(selector_or_expr)
              end
        target = sel.context ? RuntimeExpression.evaluate(sel.context, context) : context
        type_name, _ver = CriterionEvaluator.extract_type_and_version(sel.type)

        case type_name
        when nil, 'jsonpointer' then RuntimeExpression.resolve_json_pointer(target, sel.selector.to_s)
        when 'jsonpath' then query_jsonpath(target, sel.selector.to_s)
        when 'xpath' then query_xpath(target.to_s, sel.selector.to_s)
        when 'regex'
          match = Regexp.new(sel.selector.to_s).match(target.to_s)
          match ? (match[1] || match[0]) : nil
        else
          raise Cdd::RuntimeExpressionError, "Unsupported selector type: #{type_name}"
        end
      end

      # Executes a lightweight RFC 9535 JSONPath query against `data`.
      #
      # @param data [Object] parsed JSON object or JSON string
      # @param query [String] JSONPath expression (`$.a.b[0]`, `$[?(@.status == 'available')]`)
      # @return [Object] matched value or nil
      def self.query_jsonpath(data, query)
        parsed = RuntimeExpression.parse_json_if_string(data)
        return apply_jsonpath_filter(parsed, Regexp.last_match(1)) if query =~ /\A\$\[\?\((.+)\)\]\z/

        cleaned = query.sub(/\A\$\.?/, '')
        return parsed if cleaned.empty?

        tokens = cleaned.scan(/([a-zA-Z0-9_-]+)|\[(\d+)\]/).map { |k, idx| k || idx }
        tokens.reduce(parsed) do |acc, tok|
          break nil if acc.nil?

          acc = RuntimeExpression.parse_json_if_string(acc)
          acc.is_a?(Array) && tok.match?(/\A\d+\z/) ? acc[tok.to_i] : RuntimeExpression.fetch_ctx(acc, tok.to_sym)
        end
      end

      # Evaluates a JSONPath filter expression `@.<field> == <val>` against an Array.
      #
      # @param list [Object] target array
      # @param filter_expr [String] filter predicate
      # @return [Array<Object>] matching items
      def self.apply_jsonpath_filter(list, filter_expr)
        return [] unless list.is_a?(Array) && filter_expr =~ /\A@\.([a-zA-Z0-9_]+)\s*(==|!=)\s*(.+)\z/

        field = Regexp.last_match(1).to_sym
        op = Regexp.last_match(2)
        rhs = CriterionEvaluator.resolve_operand(Regexp.last_match(3).strip, nil, {})
        list.select do |item|
          val = RuntimeExpression.fetch_ctx(item, field)
          CriterionEvaluator.values_match?(val, op, rhs)
        end
      end

      # Executes an XPath query against an XML string.
      #
      # @param xml_str [String] XML content
      # @param xpath_expr [String] XPath expression
      # @return [String, nil] matched node text or attribute value
      def self.query_xpath(xml_str, xpath_expr)
        xml = xml_str.to_s
        return nil unless xml.include?('<') && xml.scan(/<[^>]*\z/).empty?

        target = xpath_expr.to_s.split('/').reject(&:empty?)
        last = target.last.to_s
        match = if last.start_with?('@')
                  tag = target[-2].to_s
                  attr = last.sub(/\A@/, '')
                  xml.match(/<#{Regexp.escape(tag)}\b[^>]*\b#{Regexp.escape(attr)}=['"]([^'"]*)['"]/m)
                else
                  tag = last.sub(/\[\d+\]\z/, '')
                  xml.match(%r{<#{Regexp.escape(tag)}(?:\s[^>]*)?>(.*?)</#{Regexp.escape(tag)}>}m)
                end
        match ? match[1] : nil
      end
    end

    # Applies Arazzo 1.1.0 `PayloadReplacement` rules onto a request body payload.
    class PayloadReplacer
      # Applies all `replacements` to `payload` evaluated against `context`.
      #
      # @param payload [Object] base payload (Hash, Array, or String)
      # @param replacements [Array<Cdd::IR::PayloadReplacement, Hash>] replacement rules
      # @param context [Hash] runtime state context
      # @return [Object] modified payload copy
      # @raise [Cdd::RuntimeExpressionError] when an unsupported targetSelectorType is encountered
      def self.apply(payload, replacements, context = {})
        base = RuntimeExpression.evaluate(deep_copy(payload), context)
        return base if replacements.nil? || replacements.empty?

        replacements.reduce(base) do |current, rep|
          r_obj = if rep.is_a?(Cdd::IR::PayloadReplacement)
                    rep
                  else
                    Cdd::IR::PayloadReplacement.new(
                      target: rep['target'],
                      target_selector_type: rep['targetSelectorType'],
                      value: rep['value'],
                      extensions: Cdd::IR.extract_extensions(rep)
                    )
                  end
          val = RuntimeExpression.evaluate(r_obj.value, context)
          apply_single(current, r_obj.target.to_s, r_obj.target_selector_type, val)
        end
      end

      # Applies a single replacement to `current` using `target` and `selector_type`.
      #
      # @param current [Object] payload being mutated
      # @param target [String] target pointer/path
      # @param selector_type [String, Cdd::IR::ExpressionType, Hash, nil] selector dialect
      # @param val [Object] resolved replacement value
      # @return [Object] updated payload
      # @raise [Cdd::RuntimeExpressionError] when an unknown selector dialect is given
      def self.apply_single(current, target, selector_type, val)
        type_name, _ver = CriterionEvaluator.extract_type_and_version(selector_type)
        case type_name
        when nil, 'jsonpointer'
          replace_json_pointer(current, target, val)
        when 'jsonpath'
          ptr = "/#{target.sub(/\A\$\.?/, '').tr('.', '/')}"
          replace_json_pointer(current, ptr, val)
        when 'xpath'
          replace_xpath(current.to_s, target, val)
        else
          raise Cdd::RuntimeExpressionError, "Unsupported replacement selector type: #{type_name}"
        end
      end

      # Replaces a value at an RFC 6901 JSON Pointer location in `data`.
      #
      # @param data [Object] Hash or Array payload
      # @param pointer [String] RFC 6901 pointer
      # @param val [Object] replacement value
      # @return [Object] updated payload
      def self.replace_json_pointer(data, pointer, val)
        return val if pointer.empty? || pointer == '/'

        segments = pointer.sub(%r{\A/}, '').split('/').map { |s| s.gsub('~1', '/').gsub('~0', '~') }
        parent = navigate_pointer_parent(data, segments[0...-1])
        last = segments.last
        if parent.is_a?(Array) && last.match?(/\A\d+\z/)
          parent[last.to_i] = val
        elsif parent.is_a?(Hash)
          parent[last] = val
        end
        data
      end

      # Navigates or creates intermediate containers along `segments`.
      #
      # @param data [Object] root payload
      # @param segments [Array<String>] parent pointer segments
      # @return [Object] resolved parent container
      def self.navigate_pointer_parent(data, segments)
        segments.reduce(data) do |acc, seg|
          if acc.is_a?(Array)
            acc[seg.to_i]
          elsif acc.is_a?(Hash)
            acc[seg] ||= {}
          end
        end
      end

      # Replaces the text of the first matching XPath node in `xml_str`.
      #
      # @param xml_str [String] XML payload string
      # @param xpath_expr [String] XPath target
      # @param val [Object] replacement value
      # @return [String] updated XML string
      def self.replace_xpath(xml_str, xpath_expr, val)
        tag = xpath_expr.to_s.split('/').reject(&:empty?).last.to_s.sub(/\[\d+\]\z/, '')
        xml_str.to_s.sub(%r{(<#{Regexp.escape(tag)}(?:\s[^>]*)?>).*?(</#{Regexp.escape(tag)}>)}m, "\\1#{val}\\2")
      end

      # Deep-duplicates a JSON-compatible Ruby object.
      #
      # @param obj [Object] value to clone
      # @return [Object] deep copy
      def self.deep_copy(obj)
        case obj
        when Hash then obj.transform_values { |v| deep_copy(v) }
        when Array then obj.map { |v| deep_copy(v) }
        else obj
        end
      end
    end
  end
end
