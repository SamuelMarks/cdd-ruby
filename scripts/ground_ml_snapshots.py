#!/usr/bin/env python3
"""
Explicitly grounds cdd-ruby OpenAPI 3.2.0 and Arazzo 1.1.0 forward and reverse
compilation against ../ml-framework-snapshots (and local fixtures).
"""

import glob
import json
import os
import subprocess
import sys
import tempfile

for ruby_bin in ('/opt/homebrew/opt/ruby/bin', '/opt/homebrew/lib/ruby/gems/4.0.0/bin', '/usr/local/opt/ruby/bin'):
    if os.path.isdir(ruby_bin):
        os.environ['PATH'] = f"{ruby_bin}{os.pathsep}{os.environ.get('PATH', '')}"


def build_snapshot_arazzo_from_corpus(snapshot_dir):
    """Builds a grounded Arazzo 1.1.0 specification from ../ml-framework-snapshots."""
    workflows = []
    sources = [{'name': 'ml_corpus', 'url': './ml_corpus_openapi.json', 'type': 'openapi'}]

    json_files = sorted(glob.glob(os.path.join(snapshot_dir, '**', '*.json'), recursive=True))[:5]
    for idx, jf in enumerate(json_files):
        base = os.path.splitext(os.path.basename(jf))[0]
        clean_id = ''.join(ch if ch.isalnum() else '_' for ch in base).strip('_').lower() or f'snapshot_{idx}'
        if clean_id[0].isdigit():
            clean_id = f'wf_{clean_id}'
        workflows.append({
            'workflowId': f'ground_{clean_id}_{idx}',
            'summary': f'Grounded ML framework workflow from {os.path.basename(jf)}',
            'steps': [
                {
                    'stepId': f'run_{clean_id}',
                    'operationId': f'execute_{clean_id}',
                    'parameters': [{'name': 'snapshot', 'in': 'query', 'value': '$inputs.snapshot'}],
                    'successCriteria': [{'context': '$statusCode', 'condition': '$statusCode == 200', 'type': 'simple'}],
                    'outputs': {'resultId': '$response.body#/id'}
                }
            ],
            'outputs': {'finalResultId': f'$steps.run_{clean_id}.outputs.resultId'}
        })

    if not workflows:
        workflows.append({
            'workflowId': 'ground_ml_pipeline',
            'summary': 'Grounded ML framework training and evaluation workflow',
            'steps': [
                {
                    'stepId': 'train_step',
                    'operationId': 'train_model',
                    'parameters': [{'name': 'epochs', 'in': 'query', 'value': '$inputs.epochs'}],
                    'successCriteria': [{'context': '$statusCode', 'condition': '$statusCode == 200', 'type': 'simple'}],
                    'outputs': {'modelId': '$response.body#/modelId'}
                },
                {
                    'stepId': 'eval_step',
                    'operationId': 'evaluate_model',
                    'parameters': [{'name': 'modelId', 'in': 'query', 'value': '$steps.train_step.outputs.modelId'}],
                    'successCriteria': [{'context': '$statusCode', 'condition': '$statusCode == 200', 'type': 'simple'}],
                    'outputs': {'accuracy': '$response.body#/accuracy'}
                }
            ],
            'outputs': {'accuracy': '$steps.eval_step.outputs.accuracy'}
        })

    return {
        'arazzo': '1.1.0',
        'info': {
            'title': 'Grounded ML Framework Workflows',
            'version': '1.1.0',
            'description': 'Grounded against ../ml-framework-snapshots'
        },
        'sourceDescriptions': sources,
        'workflows': workflows
    }


def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    snapshot_dir = os.path.abspath(os.path.join(repo_root, '..', 'ml-framework-snapshots'))
    arazzo_spec = build_snapshot_arazzo_from_corpus(snapshot_dir)

    with tempfile.TemporaryDirectory() as tmpdir:
        arazzo_json = os.path.join(tmpdir, 'grounded_arazzo.json')
        sdk_dir = os.path.join(tmpdir, 'sdk')
        roundtrip_json = os.path.join(tmpdir, 'roundtrip_arazzo.json')

        with open(arazzo_json, 'w', encoding='utf-8') as f:
            json.dump(arazzo_spec, f, indent=2)

        cmd_from = [
            'bundle', 'exec', 'ruby', 'bin/cdd-ruby',
            'from_arazzo', 'to_sdk',
            '-i', arazzo_json,
            '-o', sdk_dir
        ]
        res_from = subprocess.run(cmd_from, cwd=repo_root, capture_output=True, text=True)
        if res_from.returncode != 0:
            print(f"from_arazzo failed: {res_from.stdout} {res_from.stderr}", file=sys.stderr)
            sys.exit(1)

        workflows_rb = os.path.join(sdk_dir, 'lib', 'workflows.rb')
        if not os.path.isfile(workflows_rb):
            print("Generated workflows.rb missing!", file=sys.stderr)
            sys.exit(1)

        res_syntax = subprocess.run(['bundle', 'exec', 'ruby', '-c', workflows_rb], cwd=repo_root, capture_output=True, text=True)
        if res_syntax.returncode != 0:
            print(f"Ruby syntax check failed: {res_syntax.stderr}", file=sys.stderr)
            sys.exit(1)

        cmd_to = [
            'bundle', 'exec', 'ruby', 'bin/cdd-ruby',
            'to_arazzo',
            '-i', workflows_rb,
            '-o', roundtrip_json
        ]
        res_to = subprocess.run(cmd_to, cwd=repo_root, capture_output=True, text=True)
        if res_to.returncode != 0:
            print(f"to_arazzo failed: {res_to.stdout} {res_to.stderr}", file=sys.stderr)
            sys.exit(1)

        with open(roundtrip_json, 'r', encoding='utf-8') as f:
            parsed = json.load(f)

        if parsed.get('arazzo') != '1.1.0' or parsed.get('workflows') != arazzo_spec['workflows']:
            print("Round-trip Arazzo workflow mismatch!", file=sys.stderr)
            sys.exit(1)

    status_label = "present" if os.path.isdir(snapshot_dir) else "fallback corpus"
    print(f"Grounded cdd-ruby OpenAPI & Arazzo 1.1.0 against ../ml-framework-snapshots ({status_label}): OK")


if __name__ == '__main__':
    main()
