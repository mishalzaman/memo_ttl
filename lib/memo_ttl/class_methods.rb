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
    def memoize(method_name, ttl: 60, max_size: 100)
      original_method = instance_method(method_name)
      cache_var = "@_memo_ttl_#{method_name}"

      define_memoized_method(method_name, cache_var, original_method, ttl, max_size)
    end

    private

    def define_memoized_method(method_name, cache_var, original_method, ttl, max_size)
      define_method(method_name) do |*args, &block|
        cache = fetch_or_create_cache(cache_var, ttl, max_size)
        key = build_cache_key(method_name, args, block)

        fetch_or_compute_result(cache, key, original_method, args, block)
      end
    end
  end
end
