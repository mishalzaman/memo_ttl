# frozen_string_literal: true

require_relative "cache"

module MemoTTL
  # Adds class-level method memoization.
  module ClassMethods
    # Memoizes an instance method with TTL and max size.
    #
    # @param method_name [Symbol] the name of the method to memoize
    # @param ttl [Integer] time-to-live in seconds for the memoized result
    # @param max_size [Integer] maximum number of memoized results to keep
    # @raise [NameError] if the method doesn't exist
    # @raise [ArgumentError] if ttl or max_size are invalid
    def memoize(method_name, ttl: 60, max_size: 100)
      raise ArgumentError, "ttl must be positive" unless ttl.is_a?(Numeric) && ttl.positive?
      raise ArgumentError, "max_size must be positive" unless max_size.is_a?(Integer) && max_size.positive?

      unless method_defined?(method_name) || private_method_defined?(method_name)
        raise NameError, "Method '#{method_name}' not defined in #{self}"
      end

      original_method = instance_method(method_name)
      cache_var = "@__memo_ttl_cache__#{method_name}"

      define_memoized_method(method_name, cache_var, original_method, ttl, max_size)
    end

    private

    def define_memoized_method(method_name, cache_var, original_method, ttl, max_size)
      warn "Redefining memoized method: #{method_name}" if instance_variable_defined?(cache_var)

      define_method(method_name) do |*args, &block|
        cache = fetch_or_create_cache(cache_var, ttl, max_size)
        key = build_cache_key(method_name, args, block)
        fetch_or_compute_result(cache, key, original_method, args, block)
      rescue MemoTTL::KeyGenerationError, MemoTTL::MethodBindingError, MemoTTL::CacheOperationError => e
        raise e
      rescue StandardError => e
        raise MemoTTL::Error, "Failed to execute memoized method '#{method_name}': #{e.message}"
      end
    end
  end
end
