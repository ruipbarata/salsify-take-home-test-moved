# frozen_string_literal: true

# Service for reading lines from a large file efficiently using caching.
# It stores line offsets in Redis to minimize repeated file scanning.
# The file is processed in chunks, allowing partial caching and optimized retrieval.
class FileReaderChunksService
  LINE_OFFSETS_CACHE_PREFIX = "line_offsets_block_" # Cache key prefix for storing line offsets in chunks
  LINE_CACHE_KEY_PREFIX = "line_" # Cache key prefix for storing individual lines
  CHUNK_LOCK_KEY = "chunk_lock" # Cache key for locking the processing of a chunk
  NEXT_BLOCK_CACHE_KEY = "next_line_offsets_block" # Cache key for storing the index of the next block to process
  CHUNK_SIZE = ENV.fetch("FILE_READER_CHUNK_SIZE", 1000).to_i # Number of line offsets stored per chunk

  def initialize
    @file_path = ENV["FILE_PATH"]
    @file_hash = Digest::SHA256.hexdigest(@file_path)
  end

  # Fetches a specific line from the file
  # @param index [Integer] The line index to fetch
  # @return [String, nil] The requested line or nil if it does not exist
  def fetch_line(index)
    return if index < 0

    # Try retrieving the line from cache; otherwise, read from the file
    Rails.cache.fetch(line_cache_key(index)) do
      offset = fetch_offset(index)

      offset ? read_line(offset) : nil
    end
  end

  private

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
      if redis.exists?(line_offsets_cache_key(chunk_index))
        offsets = Rails.cache.read(line_offsets_cache_key(chunk_index))
        return offsets[index % CHUNK_SIZE] if offsets
      end

      # If the offsets are not present, process and cache the chunk
      lock_acquired = Rails.cache.write(chunk_lock_key, chunk_index, unless_exist: true)
      if lock_acquired
        begin
          offsets = load_and_cache_blocks(index, chunk_index)
          return offsets[index % CHUNK_SIZE]
        ensure
          Rails.cache.delete(chunk_lock_key)
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
    next_chunk_index_to_process = Rails.cache.read(next_block_cache_key) || 0
    last_chunk_index_to_process = next_chunk_index_to_process == 0 ? 0 : next_chunk_index_to_process - 1
    start_offset = next_chunk_index_to_process == 0 ? 0 : Rails.cache.read(line_offsets_cache_key(last_chunk_index_to_process))&.last || 0

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

        Rails.cache.write(line_offsets_cache_key(curr_chunk_index), block_offsets)

        target_block_offsets = block_offsets

        break if file.eof?
      end
    end

    Rails.cache.write(next_block_cache_key, target_chunk_index + 1)

    target_block_offsets
  end

  # Generates the cache key for storing line offsets of a specific chunk
  # @param chunk_index [Integer] The index of the chunk
  # @return [String] The cache key for the chunk's line offsets
  def line_offsets_cache_key(chunk_index)
    "#{@file_hash}:#{LINE_OFFSETS_CACHE_PREFIX}#{chunk_index}"
  end

  # Generates the cache key for storing a specific line
  # @param index [Integer] The line index
  # @return [String] The cache key for the line
  def line_cache_key(index)
    "#{@file_hash}:#{LINE_CACHE_KEY_PREFIX}#{index}"
  end

  # Generates the cache key for locking the processing of a chunk
  # @return [String] The cache key for the chunk lock
  def chunk_lock_key
    "#{@file_hash}:#{CHUNK_LOCK_KEY}"
  end

  # Generates the cache key for storing the index of the next block to process
  # @return [String] The cache key for the next block index
  def next_block_cache_key
    "#{@file_hash}:#{NEXT_BLOCK_CACHE_KEY}"
  end

  # Initializes a Redis connection
  # @return [Redis] The Redis connection instance
  def redis
    @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379"))
  end
end
