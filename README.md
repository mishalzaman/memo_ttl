# MemoTTL

**MemoTTL** is a thread-safe memoization utility for Ruby that supports TTL (Time-To-Live) and LRU (Least Recently Used) eviction. It's designed for scenarios where memoized values should expire after a period and memory usage must be constrained.

## Features

- ⚡ Memoize method results with expiration (TTL)
- 🧠 Built-in LRU eviction to limit memory usage
- 🔒 Thread-safe with Monitor
- 🧩 Easy integration via `include MemoTTL`

## Installation

Add this line to your application's Gemfile:

```ruby
gem "memo_ttl"
```

Afterwards:

```ruby
bundle install
```

## Usage

```ruby
require "memo_ttl"

class Calculator
  include MemoTTL

  memoize :expensive_method, ttl: 60, max_size: 100

  def a_method_that_does_something(x)
    sleep(2) # simulate slow process
    x * 2
  end
end

calc = Calculator.new
calc.a_method_that_does_something(5) # takes 2 seconds
calc.a_method_that_does_something(5) # returns instantly from cache
```

To clear the cache:

```ruby
calc.clear_memoized_method(:a_method_that_does_something)
calc.clear_all_memoized_methods
calc.cleanup_memoized_methods
```