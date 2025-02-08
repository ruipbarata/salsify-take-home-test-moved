# frozen_string_literal: true

class LinesController < ApplicationController
  FILE_PATH = Rails.root.join("script/data/fiile1.dat")

  # GET /lines/1
  def show
    line_index = params[:index].to_i

    if line_index < 0
      render(plain: "Line index out of range", status: :payload_too_large)
      return
    end

    line = fetch_line_from_cache(line_index)

    if line.nil?
      render(plain: "Line index out of range", status: :payload_too_large)
    else
      render(plain: line, status: :ok)
    end
  end

  private

  def generate_index
    offsets = []
    offset = 0

    File.open(FILE_PATH, "r") do |file|
      file.each_line do |line|
        offsets << offset
        offset += line.bytesize
      end
    end

    offsets
  end

  def fetch_line_from_cache(index)
    cached_line = Rails.cache.read("line_#{index}")
    return cached_line if cached_line

    logger.debug("Cache miss for line #{index}")

    line = fetch_line(index)
    Rails.cache.write("line_#{index}", line) if line
    line
  end

  def fetch_line(index)
    line_offsets = Rails.cache.read("line_offsets")

    unless line_offsets
      line_offsets = generate_index
      Rails.cache.write("line_offsets", line_offsets.to_json)
    end

    File.open(FILE_PATH, "r") do |file|
      file.seek(line_offsets[index])
      return file.readline.chomp
    end
  end
end
