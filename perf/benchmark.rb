# rubocop:disable all

require "benchmark"
require_relative "../lib/memo_ttl"

# Simulate a heavy operation (e.g., DB query, API call)
def expensive_operation(x)
  sleep(0.1)
  x * 42
end

# Plain class
class Plain
  def compute(x)
    expensive_operation(x)
  end
end

# Memoized class
class Memoized
  include MemoTTL

  def compute(x)
    expensive_operation(x)
  end

  memoize :compute, ttl: 60, max_size: 100
end

Plain.new # frozen_string_literal: true

require "benchmark"
require_relative "../lib/memo_ttl"

def expensive_operation(val)
  sleep(0.1) # Simulates an expensive operation
  val * 42
end

class Plain
  def compute(val)
    expensive_operation(val)
  end
end

class Memoized
  include MemoTTL

  def compute(val)
    expensive_operation(val)
  end

  memoize :compute, ttl: 60, max_size: 100
end

plain    = Plain.new
memoized = Memoized.new

ITERATIONS = 10

puts "\n-- Executing plain method #{ITERATIONS} times --"
plain_time = Benchmark.realtime do
  ITERATIONS.times { plain.compute(5) }
end
puts "Total time (plain):    #{(plain_time * 1000).round(2)} ms"

puts "\n-- Executing memoized method #{ITERATIONS} times --"
memo_time = Benchmark.realtime do
  ITERATIONS.times { memoized.compute(5) }
end
puts "Total time (memoized): #{(memo_time * 1000).round(2)} ms"

puts "\n✅ Saved time: #{((plain_time - memo_time) * 1000).round(2)} ms"

memoized = Memoized.new

ITERATIONS = 10

puts "\n-- Executing plain method #{ITERATIONS} times --"
plain_time = Benchmark.realtime do
  ITERATIONS.times { plain.compute(5) }
end
puts "Total time (plain):    #{(plain_time * 1000).round(2)} ms"

puts "\n-- Executing memoized method #{ITERATIONS} times --"
memo_time = Benchmark.realtime do
  ITERATIONS.times { memoized.compute(5) }
end
puts "Total time (memoized): #{(memo_time * 1000).round(2)} ms"

puts "\n✅ Saved time: #{((plain_time - memo_time) * 1000).round(2)} ms"

# rubocop:enable all
