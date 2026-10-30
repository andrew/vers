# frozen_string_literal: true

require "test_helper"
require "timeout"

class TestConstraintCache < Minitest::Test
  def test_satisfies_when_a_cached_constraint_is_evicted_after_lookup
    assert_satisfies_during_eviction(:c_return, [:key?, :[]])
  end

  def test_satisfies_when_a_cached_constraint_is_evicted_before_lookup
    assert_satisfies_during_eviction(:c_call, [:[]])
  end

  def assert_satisfies_during_eviction(event_type, methods)
    cache = Vers::Constraint.class_variable_get(:@@constraint_cache)
    original = cache.dup
    cache.clear
    assert Vers.satisfies?("1.5.0", ">=1.0.0 <2.0.0", "npm")
    limit = Vers::Constraint.class_variable_get(:@@cache_size_limit)
    (limit - cache.size).times do |index|
      Vers.satisfies?("1.5.0", "=#{index + 10}.0.0", "npm")
    end

    start = Queue.new
    done = Queue.new
    competitor = Thread.new do
      start.pop
      begin
        Vers.satisfies?("1.5.0", "=9999.0.0", "npm")
      ensure
        done << true
      end
    end

    evicted = false
    trace = TracePoint.new(event_type) do |event|
      next unless methods.include?(event.method_id) && event.self.equal?(cache)
      next if event_type == :c_return && !event.return_value

      trace.disable
      start << true
      Timeout.timeout(5) { done.pop }
      competitor.value
      evicted = !cache.key?(">=1.0.0")
    end

    result = trace.enable(target_thread: Thread.current) do
      Vers.satisfies?("1.5.0", ">=1.0.0 <2.0.0", "npm")
    end
    assert evicted, "the competing lookup must evict the cached lower bound"
    assert result
  ensure
    trace&.disable
    competitor&.kill
    competitor&.join
    cache&.replace(original) if original
  end
end
