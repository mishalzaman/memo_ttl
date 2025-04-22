# frozen_string_literal: true

require "spec_helper"

RSpec.describe MemoTTL::Cache do
  let(:cache) { described_class.new(max_size: 3, ttl: 10) }

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
    cache.set("key4", "value4") # Should evict key1

    expect(cache.get("key1")).to be_nil
    expect(cache.get("key2")).to eq("value2")
    expect(cache.get("key3")).to eq("value3")
    expect(cache.get("key4")).to eq("value4")
  end

  it "updates LRU order when accessed" do
    cache.set("key1", "value1")
    cache.set("key2", "value2")
    cache.set("key3", "value3")

    cache.get("key1") # move key1 to front
    cache.set("key4", "value4") # evicts key2

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
      expect(cache.get("expire1")).to be_nil
      expect(cache.get("expire2")).to be_nil
      expect(cache.get("expire3")).to be_nil
    end
  end
end
