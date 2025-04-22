# frozen_string_literal: true

module MemoTTL
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

    # Private helper methods for memoization implementation
    private

    def fetch_or_create_cache(cache_var, ttl, max_size)
      unless instance_variable_defined?(cache_var)
        instance_variable_set(cache_var, Cache.new(ttl: ttl, max_size: max_size))
      end
      instance_variable_get(cache_var)
    end

    def build_cache_key(method_name, args, block)
      "#{object_id}-#{method_name}-#{args.map(&:hash).join("-")}-#{block&.hash}"
    end

    def fetch_or_compute_result(cache, key, original_method, args, block)
      result = cache.get(key)
      return result unless result.nil? && !cache.instance_variable_get(:@store).key?(key)

      result = original_method.bind(self).call(*args, &block)
      cache.set(key, result)
      result
    end
  end
end
