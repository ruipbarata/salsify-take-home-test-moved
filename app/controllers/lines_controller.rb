# frozen_string_literal: true

class LinesController < ApplicationController
  before_action :file_reader, only: :show

  # GET /lines/:index
  # Displays the line from the file corresponding to the provided index.
  # Params:
  # +index+:: the index of the line to be displayed (passed as a URL parameter)
  # Responses:
  # - 200 OK: Returns the line corresponding to the index.
  # - 413 Payload Too Large: If the index is out of range.
  def show
    line_index = params[:index].to_i

    line = fetch_line(line_index)

    if line.nil?
      render(plain: "Line index out of range", status: :payload_too_large)
    else
      render(plain: line, status: :ok)
    end
  end

  private

  def file_reader
    @file_reader ||= FileReaderChunksService.new
  end

  def fetch_line(index)
    file_reader.fetch_line(index)
  end
end
