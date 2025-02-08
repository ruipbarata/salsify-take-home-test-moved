# frozen_string_literal: true

class FileReaderService
  LINE_OFFSETS_CACHE_KEY = "line_offsets"
  LINE_CACHE_KEY = "line"

  def initialize
    @file_path = ENV["FILE_PATH"]
    @line_offsets = fetch_line_offsets
  end

  def fetch_line(index)
    return if index < 0 || index >= @line_offsets.size

    Rails.cache.fetch("#{LINE_CACHE_KEY}#{index}") do
      read_line(index)
    end
  end

  private

  def fetch_line_offsets
    Rails.cache.fetch(LINE_OFFSETS_CACHE_KEY, expires_in: 1.week) do
      generate_line_offsets
    end
  end

  def generate_line_offsets
    offsets = []
    offset = 0

    File.open(@file_path, "r") do |file|
      file.each_line do |line|
        offsets << offset
        offset += line.bytesize
      end
    end

    offsets
  end

  def read_line(index)
    offset = @line_offsets[index]

    File.open(@file_path, "r") do |file|
      file.seek(offset)
      file.readline.chomp
    end
  end
end
