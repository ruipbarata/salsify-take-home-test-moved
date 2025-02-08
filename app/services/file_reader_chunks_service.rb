# frozen_string_literal: true

# Rading lines from a large file.
# It leverages caching to store line offsets in Redis, reducing the need for repeated file scanning.
# The service processes the file in chunks of a predefined size, enabling partial caching and optimized retrieval.
class FileReaderChunksService
  LINE_OFFSETS_CACHE_PREFIX = "line_offsets_block_" # Cache key prefix for storing line offsets in chunks
  LINE_CACHE_KEY_PREFIX = "line_" # Cache key prefix for storing individual lines
  CHUNK_SIZE = 1000 # Number of line offsets stored per chunk

  def initialize
    @file_path = ENV["FILE_PATH"]
  end

  # Fetches a specific line from the file
  # @param index [Integer] The line index to fetch
  # @return [String, nil] The requested line or nil if it does not exist
  def fetch_line(index)
    return if index < 0

    # Try retrieving the line from cache; otherwise, read from the file
    Rails.cache.fetch("#{LINE_CACHE_KEY_PREFIX}#{index}") do
      read_line(index)
    end
  end

  private

  # Reads a specific line from the file
  # @param index [Integer] The index of the line to read
  # @return [String, nil] The requested line or nil if it does not exist
  def read_line(index)
    offset = fetch_offset(index)
    return unless offset

    File.open(@file_path, "r") do |file|
      file.seek(offset)
      file.eof? ? nil : file.readline.chomp
    end
  end

  # Retrieves the offset for a given line index, computing it if necessary
  # @param index [Integer] The line index
  # @return [Integer, nil] The offset position in the file or nil if not found
  def fetch_offset(index)
    chunk_index = index / CHUNK_SIZE

    # Retrieve the offsets for the corresponding chunk from cache, generating it if necessary
    offsets = Rails.cache.fetch("#{LINE_OFFSETS_CACHE_PREFIX}#{chunk_index}") do
      load_and_cache_blocks(chunk_index)
    end

    offsets[index % CHUNK_SIZE]
  end

  # Processes and stores offsets for chunks of the file
  # @param target_block_index [Integer] The index of the chunk being processed
  # @return [Array<Integer>] The list of offsets for the target chunk
  def load_and_cache_blocks(target_chunk_index)
    # Retrieve the next block index to determine the starting position
    next_chunk_index_to_process = fetch_next_chunk_index_to_process
    last_chunk_index_to_process = next_chunk_index_to_process == 0 ? 0 : next_chunk_index_to_process - 1
    start_offset = next_chunk_index_to_process == 0 ? 0 : fetch_last_block_offset(last_chunk_index_to_process)

    target_block_offsets = []

    File.open(@file_path, "r") do |file|
      file.seek(start_offset)

      (next_chunk_index_to_process..target_chunk_index).each do |curr_chunk_index|
        block_offsets = []

        while block_offsets.size < CHUNK_SIZE
          break if file.eof?

          # Ensure the first line is correctly handled
          file.readline unless start_offset == 0 && block_offsets.empty? && target_block_offsets.empty?

          block_offsets << file.pos
        end

        Rails.cache.write("#{LINE_OFFSETS_CACHE_PREFIX}#{curr_chunk_index}", block_offsets)

        target_block_offsets = block_offsets

        break if file.eof?
      end
    end

    Rails.cache.write("#{LINE_OFFSETS_CACHE_PREFIX}next_block", target_chunk_index + 1)

    target_block_offsets
  end

  # Retrieves the index of the next block to be processed
  # @return [Integer] The next block index
  def fetch_next_chunk_index_to_process
    Rails.cache.read("#{LINE_OFFSETS_CACHE_PREFIX}next_block") || 0
  end

  # Retrieves the last stored offset of a given block from Redis
  # @param block_index [Integer] The block index
  # @return [Integer] The last offset of the specified block, or 0 if none exists
  def fetch_last_block_offset(chunk_index)
    Rails.cache.read("#{LINE_OFFSETS_CACHE_PREFIX}#{chunk_index}")&.last || 0
  end
end
