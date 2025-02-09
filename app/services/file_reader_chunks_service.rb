# frozen_string_literal: true

# Rading lines from a large file.
# It leverages caching to store line offsets in Redis, reducing the need for repeated file scanning.
# The service processes the file in chunks of a predefined size, enabling partial caching and optimized retrieval.
class FileReaderChunksService
  LINE_OFFSETS_CACHE_PREFIX = "line_offsets_block_" # Cache key prefix for storing line offsets in chunks
  LINE_CACHE_KEY_PREFIX = "line_" # Cache key prefix for storing individual lines
  CHUNK_LOCK_KEY = "chunk_lock" # Cache key for locking the processing of a chunk
  NEXT_BLOCK_CACHE_KEY = "next_line_offsets_block" # Cache key for storing the index of the next block to process
  CHUNK_SIZE = ENV.fetch("FILE_READER_CHUNK_SIZE", 1000).to_i # Number of line offsets stored per chunk

  def initialize
    @file_path = ENV["FILE_PATH"]
  end

  # Fetches a specific line from the file
  # @param index [Integer] The line index to fetch
  # @return [String, nil] The requested line or nil if it does not exist
  def fetch_line(index)
    return if index < 0

    # Try retrieving the line from cache; otherwise, read from the file
    Rails.cache.fetch("#{@file_path}:#{LINE_CACHE_KEY_PREFIX}#{index}") do
      offset = fetch_offset(index)
      return unless offset

      read_line(offset)
    end
  end

  private

  # Initializes a Redis connection
  # @return [Redis] The Redis connection instance
  def redis
    @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379"))
  end

  # Reads a specific line from the file
  # @param offset [Integer] The start position of the line to read
  # @return [String, nil] The requested line or nil if it is out of bounds
  def read_line(offset)
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

    loop do
      # This is a workaround: for some reason, if there is no match in cache the first time we try to read the
      # cache, it will return nil - witch is correct. But if we try to read it again, it will continue to return nil,
      # even if there is a match in cache created by other instance.
      # My theory is that Rails is caching the request to cache :D but I have not found any prof of that.
      # Even if I do Rails.cache.exist?(key).
      # To resolve this, I am using Redis directly to check if the key exists.
      if redis.exists?("#{@file_path}:#{LINE_OFFSETS_CACHE_PREFIX}#{chunk_index}")
        offsets = Rails.cache.read("#{@file_path}:#{LINE_OFFSETS_CACHE_PREFIX}#{chunk_index}")
        return offsets[index % CHUNK_SIZE] if offsets
      end

      # If the offsets are not present, process and cache the chunk
      lock_acquired = Rails.cache.write("#{@file_path}:#{CHUNK_LOCK_KEY}", chunk_index, unless_exist: true)
      if lock_acquired
        begin
          offsets = load_and_cache_blocks(index, chunk_index)
          return offsets[index % CHUNK_SIZE]
        ensure
          Rails.cache.delete("#{@file_path}:#{CHUNK_LOCK_KEY}")
        end
      end

      sleep(1)
    end
  end

  # Processes and stores offsets for chunks of the file
  # @param target_block_index [Integer] The index of the chunk being processed
  # @return [Array<Integer>] The list of offsets for the target chunk
  def load_and_cache_blocks(index, target_chunk_index)
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

        Rails.cache.write("#{@file_path}:#{LINE_OFFSETS_CACHE_PREFIX}#{curr_chunk_index}", block_offsets)

        target_block_offsets = block_offsets

        break if file.eof?
      end
    end

    Rails.cache.write("#{@file_path}:#{NEXT_BLOCK_CACHE_KEY}", target_chunk_index + 1)

    target_block_offsets
  end

  # Retrieves the index of the next block to be processed
  # @return [Integer] The next block index
  def fetch_next_chunk_index_to_process
    Rails.cache.read("#{@file_path}:#{NEXT_BLOCK_CACHE_KEY}") || 0
  end

  # Retrieves the last stored offset of a given block from Redis
  # @param block_index [Integer] The block index
  # @return [Integer] The last offset of the specified block, or 0 if none exists
  def fetch_last_block_offset(chunk_index)
    Rails.cache.read("#{@file_path}:#{LINE_OFFSETS_CACHE_PREFIX}#{chunk_index}")&.last || 0
  end
end
