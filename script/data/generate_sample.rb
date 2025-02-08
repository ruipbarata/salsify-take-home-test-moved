# frozen_string_literal: true

n = ARGV[0].to_i

Dir.mkdir("script/data") unless Dir.exist?("script/data")

File.open("script/data/sample_#{n}.dat", "w") do |file|
  (0...n).each do |i|
    file.puts("Line #{i}")
  end
end

puts "File script/data/sample_#{n}.dat created"
