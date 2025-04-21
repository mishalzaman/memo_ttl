# spec/memo_ttl_spec.rb

require "spec_helper"

RSpec.describe MemoTTL do
  describe "Cache" do
    let(:cache) { MemoTTL::Cache.new(max_size: 3, ttl: 10) }

    it "stores and retrieves values" do
      cache.set("key1", "value1")
      expect(cache.get("key1")).to eq("value1")
    end

    it "returns nil for non-existent keys" do
      expect(cache.get("non-existent")).to be_nil
    end

    it "properly handles nil values" do
      cache.set("nil-key", nil)
      expect(cache.get("nil-key")).to be_nil
    end

    it "evicts oldest entries when max size is reached" do
      cache.set("key1", "value1")
      cache.set("key2", "value2")
      cache.set("key3", "value3")
      cache.set("key4", "value4") # This should evict key1

      expect(cache.get("key1")).to be_nil
      expect(cache.get("key2")).to eq("value2")
      expect(cache.get("key3")).to eq("value3")
      expect(cache.get("key4")).to eq("value4")
    end

    it "updates LRU order when accessed" do
      cache.set("key1", "value1")
      cache.set("key2", "value2")
      cache.set("key3", "value3")
      
      # Access key1 to move it to the front
      cache.get("key1")
      
      # Add a fourth entry, which should now evict key2 instead of key1
      cache.set("key4", "value4")

      expect(cache.get("key1")).to eq("value1")
      expect(cache.get("key2")).to be_nil
      expect(cache.get("key3")).to eq("value3")
      expect(cache.get("key4")).to eq("value4")
    end

    it "expires entries after TTL" do
      cache.set("ttl-key", "ttl-value")
      
      Timecop.travel(Time.now + 5) do
        expect(cache.get("ttl-key")).to eq("ttl-value")
      end
      
      Timecop.travel(Time.now + 11) do
        expect(cache.get("ttl-key")).to be_nil
      end
    end

    it "cleans up expired entries when cleanup is called" do
      cache.set("expire1", "value1")
      cache.set("expire2", "value2")
      cache.set("expire3", "value3")

      Timecop.travel(Time.now + 11) do
        cache.cleanup
        # All entries should be gone after cleanup
        expect(cache.get("expire1")).to be_nil
        expect(cache.get("expire2")).to be_nil
        expect(cache.get("expire3")).to be_nil
      end
    end
  end

  describe "Module Integration" do
    before do
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
    end

    after do
      Object.send(:remove_const, :TestClass)
    end

    let(:test_instance) { TestClass.new }
    let(:another_instance) { TestClass.new }

    it "memoizes method results" do
      result1 = test_instance.expensive_calculation(5)
      result2 = test_instance.expensive_calculation(5)
      
      expect(result1).to eq(10)
      expect(result2).to eq(10)
      expect(test_instance.calculation_count).to eq(1) # Called only once
    end

    it "handles different arguments separately" do
      test_instance.expensive_calculation(5)
      test_instance.expensive_calculation(10)
      
      expect(test_instance.calculation_count).to eq(2) # Called twice with different args
    end

    it "maintains separate caches per instance" do
      test_instance.expensive_calculation(5)
      another_instance.expensive_calculation(5)
      
      expect(test_instance.calculation_count).to eq(1)
      expect(another_instance.calculation_count).to eq(1)
    end

    it "expires memoized results after TTL" do
      test_instance.expensive_calculation(5)
      
      Timecop.travel(Time.now + 11) do
        test_instance.expensive_calculation(5)
        expect(test_instance.calculation_count).to eq(2) # Called again after expiry
      end
    end

    it "evicts least recently used entries when max size is reached" do
      test_instance.expensive_calculation(1)
      test_instance.expensive_calculation(2)
      
      # This should evict the result for arg=1
      test_instance.expensive_calculation(3)
      
      # This should recalculate since it was evicted
      test_instance.expensive_calculation(1)
      
      expect(test_instance.calculation_count).to eq(4)
    end

    it "correctly handles nil return values" do
      result1 = test_instance.nil_returning_method
      result2 = test_instance.nil_returning_method
      
      expect(result1).to be_nil
      expect(result2).to be_nil
      expect(test_instance.calculation_count).to eq(1) # Called only once
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