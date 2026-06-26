#!/usr/bin/env python3
import os
import subprocess
import re
import sys

# Run tests and capture output
output = subprocess.run(['bundle', 'exec', 'rspec'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True).stdout

test_cov = 0.0
match = re.search(r'LOC\s+\(([\d.]+)%\)\s+covered', output)
if match:
    test_cov = float(match.group(1))

# Get Doc Coverage
doc_cov_str = subprocess.run(['bundle', 'exec', 'yard', 'stats', 'src/**/*.rb'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True).stdout
doc_cov = 0.0
match = re.search(r'([\d.]+)\s*%', doc_cov_str)
if match:
    doc_cov = float(match.group(1))

def color_for(cov):
    if cov >= 95: return 'brightgreen'
    if cov >= 80: return 'green'
    if cov >= 60: return 'yellow'
    return 'red'

test_color = color_for(test_cov)
doc_color = color_for(doc_cov)

test_badge = f"[![Test Coverage](https://img.shields.io/badge/coverage-{test_cov:.2f}%25-{test_color}.svg)]()"
doc_badge = f"[![Doc Coverage](https://img.shields.io/badge/docs-{doc_cov:.2f}%25-{doc_color}.svg)]()"

badge_str = f"{test_badge}\n{doc_badge}"

for readme_path in ['README.md', 'ARCHITECTURE.md']:
    if not os.path.exists(readme_path):
        continue
    
    with open(readme_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    content = re.sub(r'<!-- COVERAGE_BADGES_START -->.*?<!-- COVERAGE_BADGES_END -->',
                     f"<!-- COVERAGE_BADGES_START -->\n{badge_str}\n<!-- COVERAGE_BADGES_END -->",
                     content, flags=re.DOTALL)
    
    with open(readme_path, 'w', encoding='utf-8') as f:
        f.write(content)

print(f"Updated shields with Test Coverage: {test_cov:.2f}%, Doc Coverage: {doc_cov:.2f}%")
