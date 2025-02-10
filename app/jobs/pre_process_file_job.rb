# frozen_string_literal: true

class PreProcessFileJob < ApplicationJob
  queue_as :default

  def perform(*args)
    file_reader.fetch_line(2**63 - 1)
  end

  private

  def file_reader
    @file_reader ||= FileReaderChunksService.new
  end
end
