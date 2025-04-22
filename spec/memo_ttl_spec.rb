# frozen_string_literal: true

require "spec_helper"

class TestClass
  include MemoTTL

  attr_reader :calculation_count

  def initialize
    @calculation_count = 0
  end

  def expensive_calculation(arg)
    @calculation_count += 1
    arg * 2
  end
  memoize :expensive_calculation, ttl: 10, max_size: 2

  def nil_returning_method
    @calculation_count += 1
    nil
  end
  memoize :nil_returning_method
end

RSpec.describe MemoTTL do
  let(:test_instance) { TestClass.new }
  let(:another_instance) { TestClass.new }

  describe "memoization behavior" do
    it "memoizes method results" do
      result1 = test_instance.expensive_calculation(5)
      result2 = test_instance.expensive_calculation(5)
      expect(result1).to eq(10)
      expect(result2).to eq(10)
      expect(test_instance.calculation_count).to eq(1)
    end

    it "handles different arguments separately" do
      test_instance.expensive_calculation(5)
      test_instance.expensive_calculation(10)
      expect(test_instance.calculation_count).to eq(2)
    end

    it "maintains separate caches per instance" do
      test_instance.expensive_calculation(5)
      another_instance.expensive_calculation(5)
      expect(test_instance.calculation_count).to eq(1)
      expect(another_instance.calculation_count).to eq(1)
    end
  end

  describe "ttl and lru eviction" do
    it "expires memoized results after TTL" do
      test_instance.expensive_calculation(5)
      Timecop.travel(Time.now + 11) do
        test_instance.expensive_calculation(5)
        expect(test_instance.calculation_count).to eq(2)
      end
    end

    it "evicts least recently used entries when max size is reached" do
      test_instance.expensive_calculation(1)
      test_instance.expensive_calculation(2)
      test_instance.expensive_calculation(3)
      test_instance.expensive_calculation(1)
      expect(test_instance.calculation_count).to eq(4)
    end
  end

  describe "clearing and nil values" do
    it "handles nil return values" do
      result1 = test_instance.nil_returning_method
      result2 = test_instance.nil_returning_method
      expect(result1).to be_nil
      expect(result2).to be_nil
      expect(test_instance.calculation_count).to eq(1)
    end

    it "clears specific memoized methods" do
      test_instance.expensive_calculation(5)
      test_instance.clear_memoized_method(:expensive_calculation)
      test_instance.expensive_calculation(5)
      expect(test_instance.calculation_count).to eq(2)
    end

    it "clears all memoized methods" do
      test_instance.expensive_calculation(5)
      test_instance.nil_returning_method
      test_instance.clear_all_memoized_methods
      test_instance.expensive_calculation(5)
      test_instance.nil_returning_method
      expect(test_instance.calculation_count).to eq(4)
    end

    it "cleans up expired entries" do
      test_instance.expensive_calculation(5)
      Timecop.travel(Time.now + 11) do
        test_instance.cleanup_memoized_methods
        test_instance.expensive_calculation(5)
        expect(test_instance.calculation_count).to eq(2)
      end
    end
  end
end
