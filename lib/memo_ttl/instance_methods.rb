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
  end
end
