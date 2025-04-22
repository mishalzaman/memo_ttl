# frozen_string_literal: true

module MemoTTL
  # Provides instance-level methods to manage memoized caches.
  module InstanceMethods
    # Clears the cache for a specific memoized method.
    #
    # @param method_name [Symbol] the method whose cache to clear
    # @return [Boolean] true if cache was cleared, false if not found
    def clear_memoized_method(method_name)
      cache_var = "@_memo_ttl_#{method_name}"
      if instance_variable_defined?(cache_var)
        remove_instance_variable(cache_var)
        true
      else
        false
      end
    end

    # Clears all memoized method caches for the current instance.
    #
    # @return [Integer] number of caches cleared
    def clear_all_memoized_methods
      count = 0
      instance_variables.each do |var|
        if var.to_s.start_with?("@_memo_ttl_")
          remove_instance_variable(var)
          count += 1
        end
      end
      count
    end

    # Cleans up expired entries in all memoized caches.
    #
    # @return [Hash] results of cleanup operation for each cache
    def cleanup_memoized_methods
      results = {}
      instance_variables.each do |var|
        next unless var.to_s.start_with?("@_memo_ttl_")

        method_name = var.to_s.sub("@_memo_ttl_", "").to_sym
        cache = instance_variable_get(var)

        begin
          cache.cleanup
          results[method_name] = :success
        rescue MemoTTL::CacheOperationError => e
          results[method_name] = e.message
        end
      end
      results
    end

    # Private helper methods for memoization implementation
    private

    def fetch_or_create_cache(cache_var, ttl, max_size)
      unless instance_variable_defined?(cache_var)
        begin
          instance_variable_set(cache_var, Cache.new(ttl: ttl, max_size: max_size))
        rescue ArgumentError => e
          raise MemoTTL::Error, "Failed to create cache: #{e.message}"
        end
      end
      instance_variable_get(cache_var)
    end

    def build_cache_key(method_name, args, block)
      arg_hashes = args.map do |arg|
        arg.hash
      rescue NoMethodError
        # For objects without hash method
        arg.object_id
      end

      block_hash = block.nil? ? "no_block" : block.hash.to_s

      "#{object_id}-#{method_name}-#{arg_hashes.join("-")}-#{block_hash}"
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
        # Let application errors propagate normally, but don't cache them
        raise e
      end

      # Only cache the result if method executed successfully
      cache.set(key, result)
      result
    end
  end
end
