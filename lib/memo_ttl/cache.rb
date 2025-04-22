# frozen_string_literal: true

require "monitor"

module MemoTTL
  # Internal cache with TTL (time-to-live) and max size enforcement.
  class Cache
    # Special object used to represent `nil` values safely.
    NULL_OBJECT = Object.new.freeze

    # Structure to hold a cached value and its expiration timestamp.
    Entry = Struct.new(:value, :expires_at)

    # Initializes a new Cache.
    #
    # @param max_size [Integer] maximum number of entries to keep
    # @param ttl [Integer] time-to-live in seconds for each entry
    # @raise [ArgumentError] if max_size or ttl are not positive integers
    def initialize(max_size: 100, ttl: 60)
      raise ArgumentError, "max_size must be a positive integer" unless max_size.is_a?(Integer) && max_size.positive?

      raise ArgumentError, "ttl must be a positive integer" unless ttl.is_a?(Integer) && ttl.positive?

      @max_size = max_size
      @ttl = ttl
      @store = {}
      @order = []
      @lock = Monitor.new
    end

    # Retrieves the cached value for a key, or nil if not present or expired.
    #
    # @param key [Object] the key to retrieve
    # @return [Object, nil] the cached value or nil
    # @raise [CacheOperationError] if there's an issue accessing the cache
    def get(key)
      @lock.synchronize do
        entry = @store[key]
        return nil unless entry

        if entry.expires_at && Time.now > entry.expires_at
          delete(key)
          return nil
        end
        touch(key)
        entry.value == NULL_OBJECT ? nil : entry.value
      rescue StandardError => e
        raise CacheOperationError, "Failed to get key #{key}: #{e.message}"
      end
    end

    # Stores a value in the cache under the given key.
    #
    # @param key [Object] the key to store under
    # @param value [Object, nil] the value to store
    # @return [Object] the value that was stored
    # @raise [CacheOperationError] if there's an issue storing in the cache
    def set(key, value)
      @lock.synchronize do
        delete(key) if @store.key?(key)
        evict if @store.size >= @max_size
        stored_value = value.nil? ? NULL_OBJECT : value
        @store[key] = Entry.new(stored_value, Time.now + @ttl)
        @order.unshift(key)
        value
      rescue StandardError => e
        raise CacheOperationError, "Failed to set key #{key}: #{e.message}"
      end
    end

    # Removes all expired entries from the cache.
    #
    # @return [void]
    # @raise [CacheOperationError] if there's an issue during cleanup
    def cleanup
      @lock.synchronize do
        now = Time.now
        expired_keys = @store.select { |_key, entry| entry.expires_at && now > entry.expires_at }.keys
        expired_keys.each { |key| delete(key) }
      rescue StandardError => e
        raise CacheOperationError, "Failed during cache cleanup: #{e.message}"
      end
    end

    # Checks if a key exists in the cache, regardless of its value
    #
    # @param key [Object] the key to check
    # @return [Boolean] true if the key exists, false otherwise
    def key?(key)
      @lock.synchronize { @store.key?(key) }
    end

    private

    # Deletes an entry by key.
    #
    # @param key [Object] the key to remove
    def delete(key)
      @store.delete(key)
      @order.delete(key)
    end

    # Marks a key as most recently used.
    #
    # @param key [Object] the key to touch
    def touch(key)
      @order.delete(key)
      @order.unshift(key)
    end

    # Removes the least recently used entry.
    #
    # @return [void]
    def evict
      oldest_key = @order.pop
      @store.delete(oldest_key)
    end
  end
end
