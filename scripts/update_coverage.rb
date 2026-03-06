#!/usr/bin/env ruby
require 'json'

# Run tests and capture output
output = `bundle exec rspec 2>&1`

test_cov = 0.0
if output =~ /LOC\s+\(([\d\.]+)\%\)\s+covered/
  test_cov = $1.to_f
end

# Get Doc Coverage
doc_cov_str = `bundle exec yard stats "src/**/*.rb" 2>/dev/null | grep "% documented"`
doc_cov = 0.0
if doc_cov_str =~ /([\d\.]+)\s*%/
  doc_cov = $1.to_f
end

def color_for(cov)
  if cov >= 95
    "brightgreen"
  elsif cov >= 80
    "green"
  elsif cov >= 60
    "yellow"
  else
    "red"
  end
end

test_color = color_for(test_cov)
doc_color = color_for(doc_cov)

test_badge = "[![Test Coverage](https://img.shields.io/badge/coverage-#{test_cov.round(2)}%25-#{test_color}.svg)]()"
doc_badge = "[![Doc Coverage](https://img.shields.io/badge/docs-#{doc_cov.round(2)}%25-#{doc_color}.svg)]()"

badge_str = "#{test_badge}\n#{doc_badge}"

["README.md", "ARCHITECTURE.md"].each do |readme_path|
  if File.exist?(readme_path)
    content = File.read(readme_path)
    
    # Replace between the tags
    content.sub!(/<!-- COVERAGE_BADGES_START -->.*?<!-- COVERAGE_BADGES_END -->/m, "<!-- COVERAGE_BADGES_START -->\n#{badge_str}\n<!-- COVERAGE_BADGES_END -->")
    
    File.write(readme_path, content)
  end
end

puts "Updated shields with Test Coverage: #{test_cov.round(2)}%, Doc Coverage: #{doc_cov.round(2)}%"
