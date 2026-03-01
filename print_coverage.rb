require 'json'
cov = JSON.parse(File.read('coverage/coverage.json'))
cov["coverage"].each do |file, data|
  lines = data["lines"]
  hits = lines.compact
  percent = (hits.count { |h| h > 0 }.to_f / hits.size * 100).round(2)
  next if percent == 100.0
  puts "#{file} (#{percent}%):"
  file_content = File.readlines(file)
  lines.each_with_index do |hit, idx|
    if hit == 0
      puts "  Line #{idx + 1}: #{file_content[idx].strip}"
    end
  end
end
