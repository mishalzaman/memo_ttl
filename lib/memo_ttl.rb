# frozen_string_literal: true

require "memo_ttl/version"
require "monitor"

# MemoTTL is a thread-safe memoization utility with TTL and LRU eviction.
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
    def initialize(max_size: 100, ttl: 60)
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
      end
    end

    # Stores a value in the cache under the given key.
    #
    # @param key [Object] the key to store under
    # @param value [Object, nil] the value to store
    # @return [Object] the value that was stored
    def set(key, value)
      @lock.synchronize do
        delete(key) if @store.key?(key)
        evict if @store.size >= @max_size
        stored_value = value.nil? ? NULL_OBJECT : value
        @store[key] = Entry.new(stored_value, Time.now + @ttl)
        @order.unshift(key)
        value
      end
    end

    # Removes all expired entries from the cache.
    #
    # @return [void]
    def cleanup
      @lock.synchronize do
        now = Time.now
        expired_keys = @store.select { |_key, entry| entry.expires_at && now > entry.expires_at }.keys
        expired_keys.each { |key| delete(key) }
      end
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

  # Adds class-level method memoization.
  module ClassMethods
    # Memoizes an instance method with TTL and max size.
    #
    # @param method_name [Symbol] the name of the method to memoize
    # @param ttl [Integer] time-to-live in seconds for the memoized result
    # @param max_size [Integer] maximum number of memoized results to keep
    def memoize(method_name, ttl: 60, max_size: 100)
      original_method = instance_method(method_name)
      cache_var = "@_memo_ttl_#{method_name}"

      define_method(method_name) do |*args, &block|
        unless instance_variable_defined?(cache_var)
          instance_variable_set(cache_var,
                                Cache.new(ttl: ttl, max_size: max_size))
        end
        cache = instance_variable_get(cache_var)

        key = "#{object_id}-#{method_name}-#{args.map(&:hash).join("-")}-#{block&.hash}"

        result = cache.get(key)
        return result unless result.nil? && !cache.instance_variable_get(:@store).key?(key)

        result = original_method.bind(self).call(*args, &block)
        cache.set(key, result)
        result
      end
    end
  end

  # Provides instance-level methods to manage memoized caches.
  module InstanceMethods
    # Clears the cache for a specific memoized method.
    #
    # @param method_name [Symbol] the method whose cache to clear
    def clear_memoized_method(method_name)
      cache_var = "@_memo_ttl_#{method_name}"
      remove_instance_variable(cache_var) if instance_variable_defined?(cache_var)
    end

    # Clears all memoized method caches for the current instance.
    def clear_all_memoized_methods
      instance_variables.each do |var|
        remove_instance_variable(var) if var.to_s.start_with?("@_memo_ttl_")
      end
    end

    # Cleans up expired entries in all memoized caches.
    def cleanup_memoized_methods
      instance_variables.each do |var|
        instance_variable_get(var).cleanup if var.to_s.start_with?("@_memo_ttl_")
      end
    end
  end

  # Hook that wires ClassMethods and InstanceMethods when the module is included.
  #
  # @param base [Class] the class including MemoTTL
  def self.included(base)
    base.extend(ClassMethods)
    base.include(InstanceMethods)
  end
end
