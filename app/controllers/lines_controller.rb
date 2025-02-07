# frozen_string_literal: true

class LinesController < ApplicationController
  FILE_PATH = Rails.root.join("script/data/fiile1.dat")
  INDEX_FILE = Rails.root.join("script/data/index.dat")

  before_action :load_index, only: [:show]

  # GET /lines/1
  def show
    line_index = params[:index].to_i

    if line_index < 0 || line_index >= @line_offsets.size
      render(plain: "Line index out of range", status: :payload_too_large)
      return
    end

    line = fetch_line(line_index)
    render(plain: line, status: :ok)
  end

  private

  def load_index
    unless File.exist?(INDEX_FILE)
      generate_index
    end

    @line_offsets = File.readlines(INDEX_FILE).map(&:to_i)
  end

  def generate_index
    offsets = []
    offset = 0

    File.open(FILE_PATH, "r") do |file|
      file.each_line do |line|
        offsets << offset
        offset += line.bytesize
      end
    end

    File.write(INDEX_FILE, offsets.join("\n"))
  end

  def fetch_line(index)
    File.open(FILE_PATH, "r") do |file|
      file.seek(@line_offsets[index])
      return file.readline.chomp
    end
  end
end
