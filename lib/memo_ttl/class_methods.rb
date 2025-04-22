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
end
