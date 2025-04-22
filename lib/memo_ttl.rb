# frozen_string_literal: true

require "memo_ttl/version"
require_relative "memo_ttl/class_methods"
require_relative "memo_ttl/instance_methods"

# MemoTTL is a thread-safe memoization utility with TTL and LRU eviction.
module MemoTTL
  class Error < StandardError; end
  class KeyGenerationError < Error; end
  class MethodBindingError < Error; end
  class CacheOperationError < Error; end

  # Hook that wires ClassMethods and InstanceMethods when the module is included.
  #
  # @param base [Class] the class including MemoTTL
  def self.included(base)
    base.extend(ClassMethods)
    base.include(InstanceMethods)
  end
end
