# frozen_string_literal: true

class FileReaderCachelessService
  INDEX_FILE = Rails.root.join("tmp/index.dat")

  def initialize
    @file_path = ENV["FILE_PATH"]
    @line_offsets = load_index
  end

  def fetch_line(index)
    File.open(@file_path, "r") do |file|
      file.seek(@line_offsets[index])
      return file.readline.chomp
    end
  end

  private

  def load_index
    unless File.exist?(INDEX_FILE)
      generate_index
    end

    line_offsets = File.readlines(INDEX_FILE).map(&:to_i)

    line_offsets
  end

  def generate_index
    offsets = []
    offset = 0

    File.open(@file_path, "r") do |file|
      file.each_line do |line|
        offsets << offset
        offset += line.bytesize
      end
    end

    File.write(INDEX_FILE, offsets.join("\n"))
  end
end
