require 'fileutils'

def find_keywords(file_paths)
  keywords = []
  file_paths.each do |f|
    next unless File.exist?(f)
    content = File.read(f)
    # Extract string literals and keys that might match openapi objects
    content.scan(/\["([^"]+)"\]/) { |m| keywords << m[0] }
    content.scan(/@api_([a-zA-Z0-9_]+)/) { |m| keywords << m[0] }
    content.scan(/["']([a-zA-Z0-9_]+)["']\s*=>/) { |m| keywords << m[0] }
    content.scan(/\.dig\([^)]*\)/).each do |dig_call|
      dig_call.scan(/["']([^"']+)["']/) { |m| keywords << m[0] }
    end
  end
  keywords.uniq
end

parse_files = Dir.glob('src/**/parse.rb')
emit_files = Dir.glob('src/**/emit.rb')
cdd_file = 'src/cdd.rb'

to_keywords = find_keywords(parse_files)

# Add some obvious ones that are root objects
to_keywords += ["openapi", "info", "servers", "paths", "components", "webhooks", "tags", "externalDocs", "security"]
from_keywords = find_keywords(emit_files + [cdd_file])
from_keywords += ["openapi", "info", "servers", "paths", "components", "webhooks", "tags", "externalDocs", "security"]

['servers.md', 'client-sdk.md', 'client-sdk-cli.md'].each do |md_file|
  path = "compliance-openapi-3-2-0/#{md_file}"
  next unless File.exist?(path)
  
  lines = File.readlines(path)
  
  total_to = 0
  total_from = 0
  checked_to = 0
  checked_from = 0
  
  new_lines = lines.map do |line|
    # Match table rows: | **OpenAPI Object (`field`)** | `[ ]` , `[ ]` | ...
    if line =~ /^\| \*\*([^*]+)\*\* \| `\[([ x])\]` , `\[([ x])\]` \|/
      obj_name = $1
      to_val = $2
      from_val = $3
      
      # extract field name, e.g., 'title' from 'Info Object (`title`)'
      # or just root object 'info' from 'OpenAPI Object (`info`)'
      field = nil
      if obj_name =~ /\(`([^`]+)`\)/
        field = $1
      elsif obj_name =~ /([^ ]+) Object/
        field = $1.downcase
      end
      
      # Handle $self, $ref, paths etc.
      field = field.sub(/^\$/, '') if field

      # Check implementation
      impl_to = to_keywords.include?(field)
      
      impl_from = false
      if md_file == 'client-sdk.md'
        impl_from = File.read(cdd_file).include?("emit_sdk") && from_keywords.include?(field)
      elsif md_file == 'client-sdk-cli.md'
        impl_from = File.read(cdd_file).include?("emit_sdk_cli") && from_keywords.include?(field)
      else
        impl_from = from_keywords.include?(field)
      end
      
      # Update markers
      new_to = impl_to ? 'x' : ' '
      new_from = impl_from ? 'x' : ' '
      
      total_to += 1
      total_from += 1
      checked_to += 1 if new_to == 'x'
      checked_from += 1 if new_from == 'x'
      
      line.sub(/\| `\[[ x]\]` , `\[[ x]\]` \|/, "| `[#{new_to}]` , `[#{new_from}]` |")
    else
      line
    end
  end
  
  File.write(path, new_lines.join)
  
  total = total_to + total_from
  checked = checked_to + checked_from
  pct = total > 0 ? (checked.to_f / total * 100).round(2) : 0.0
  puts "#{md_file}: #{pct}% (#{checked}/#{total})"
end
