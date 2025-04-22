# frozen_string_literal: true

require "digest"

module MemoTTL
  # Provides instance-level methods to manage memoized caches.
  module InstanceMethods
    # Clears the cache for a specific memoized method.
    #
    # @param method_name [Symbol] the method whose cache to clear
    # @return [Boolean] true if cache was cleared, false if not found
    def clear_memoized_method(method_name)
      cache_var = "@__memo_ttl_cache__#{method_name}"
      if instance_variable_defined?(cache_var)
        remove_instance_variable(cache_var)
        memo_registry.delete(method_name)
        true
      else
        false
      end
    end

    # Clears all memoized method caches for the current instance.
    #
    # @return [Integer] number of caches cleared
    def clear_all_memoized_methods
      return 0 unless defined?(@memo_registry)

      @memo_registry.each do |method_name|
        cache_var = "@__memo_ttl_cache__#{method_name}"
        remove_instance_variable(cache_var) if instance_variable_defined?(cache_var)
      end

      count = @memo_registry.size
      @memo_registry.clear
      count
    end

    # Cleans up expired entries in all memoized caches.
    #
    # @return [Hash] results of cleanup operation for each cache
    def cleanup_memoized_methods
      results = {}
      return results unless defined?(@memo_registry)

      @memo_registry.each do |method_name|
        cache_var = "@__memo_ttl_cache__#{method_name}"
        next unless instance_variable_defined?(cache_var)

        cache = instance_variable_get(cache_var)

        begin
          cache.cleanup
          results[method_name] = :success
        rescue MemoTTL::CacheOperationError => e
          results[method_name] = e.message
        end
      end
      results
    end

    # Checks if a memoized cache exists for a given method.
    #
    # @param method_name [Symbol]
    # @return [Boolean]
    def memoized?(method_name)
      instance_variable_defined?("@__memo_ttl_cache__#{method_name}")
    end

    private

    def memo_registry
      @memo_registry ||= Set.new
    end

    def fetch_or_create_cache(cache_var, ttl, max_size)
      return instance_variable_get(cache_var) if instance_variable_defined?(cache_var)

      begin
        cache = Cache.new(ttl: ttl, max_size: max_size)
        instance_variable_set(cache_var, cache)
        method_name = cache_var.to_s.sub("@__memo_ttl_cache__", "").to_sym
        memo_registry << method_name
        cache
      rescue ArgumentError => e
        raise MemoTTL::Error, "Failed to create cache: #{e.message}"
      end
    end

    def build_cache_key(method_name, args, block)
      block_hash =
        if block.nil?
          "no_block"
        else
          Digest::SHA256.hexdigest(block.source_location.inspect)
        end

      raw_key = [method_name, args, block_hash]
      Digest::SHA256.hexdigest(Marshal.dump(raw_key))
    rescue StandardError => e
      raise KeyGenerationError, "Failed to generate cache key: #{e.message}"
    end

    def fetch_or_compute_result(cache, key, original_method, args, block)
      result = cache.get(key)
      return result unless result.nil? && !cache.key?(key)

      begin
        result = original_method.bind(self).call(*args, &block)
      rescue NoMethodError => e
        raise MethodBindingError, "Failed to bind method: #{e.message}"
      rescue StandardError => e
        raise e
      end

      cache.set(key, result)
      result
    end
  end
end
