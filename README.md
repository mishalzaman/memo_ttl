[![Gem Version](https://badge.fury.io/rb/memo_ttl.svg)](https://rubygems.org/gems/memo_ttl)

# MemoTTL

**MemoTTL** is a thread-safe memoization utility for Ruby that supports TTL (Time-To-Live) and LRU (Least Recently Used) eviction. It's designed for scenarios where memoized values should expire after a period and memory usage must be constrained.

## Features

- Memoize method results with expiration (TTL)
- Built-in LRU eviction to limit memory usage
- Thread-safe with Monitor
- Easy integration via `include MemoTTL`

## ✅ When to Use

Use `memo_ttl` when:

- ✅ You're calling a **pure method** multiple times with the same arguments
- ✅ The method is **expensive** (I/O, DB, parsing, computation)
- ✅ You want **in-memory** caching without Redis or external dependencies
- ✅ You need **per-object isolation** — not global cache key management
- ✅ You want a cache that’s **automatically invalidated** via TTL and LRU

Avoid using it when:

- ❌ The method is already fast (e.g., simple arithmetic, inline logic)
- ❌ You're calling it with **unique arguments** every time
- ❌ You need cross-request or cross-process persistence (use `Rails.cache`)

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

  def a_method_that_does_something(x)
    sleep(2) # simulate slow process
    x * 2
  end

  # use at the bottom due to Ruby's top-down evalation of methods
  memoize :a_method_that_does_something, ttl: 60, max_size: 100
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

### Rails Example

```ruby
require 'memo_ttl'

class TestController < ApplicationController
  include MemoTTL

  def index
    result1 = test_method(1, 2)
    result2 = test_method(1, 2)
    result3 = test_method(5, 2)
    result4 = test_method(1, 2)
    result5 = test_method(1, 2)
    result6 = test_method(3, 4)

    render plain: <<~TEXT
      Result 1: #{result1}
      Result 2: #{result2}
      Result 3: #{result3}
      Result 4: #{result4}
      Result 5: #{result5}
      Result 6: #{result6}
    TEXT
  end

  def test_method(x, y)
    puts "Calling test_method(#{x}, #{y})"
    x + y
  end

  def clean_up
    clear_memoized_method(:test_method)
    clear_all_memoized_methods
    cleanup_memoized_methods
  end

  memoize :test_method, ttl: 10, max_size: 10
end
```

Output in Rails console:

```
Processing by TestController#index as HTML
Calling test_method(1, 2)
Calling test_method(5, 2)
Calling test_method(3, 4)
```
