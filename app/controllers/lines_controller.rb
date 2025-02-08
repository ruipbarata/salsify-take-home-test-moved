# frozen_string_literal: true

class LinesController < ApplicationController
  before_action :file_reader, only: :show

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
    @file_reader ||= FileReaderCachelessService.new
  end

  def fetch_line(index)
    file_reader.fetch_line(index)
  end
end
