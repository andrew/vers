# frozen_string_literal: true

require "test_helper"
require "timeout"

# Tests covering denial-of-service vectors in version and range parsing.
# These exercise resource limits at the public API boundary where untrusted
# input enters the library.
class TestSecurity < Minitest::Test
  # === Input length limits ===
  #
  # Version strings, constraint strings, and range strings flow from user
  # input straight into regex matching, String#split, and cache keys.
  # Without a length cap, a multi-megabyte string is processed end-to-end
  # and retained.

  def test_version_rejects_oversized_input
    huge = "1." + ("1." * 5000) + "1"
    assert_raises(ArgumentError) do
      Vers::Version.new(huge)
    end
  end

  def test_version_rejects_oversized_prerelease
    huge = "1.0.0-" + ("a" * 5000)
    assert_raises(ArgumentError) do
      Vers::Version.new(huge)
    end
  end

  def test_constraint_rejects_oversized_input
    huge = ">=" + ("1" * 5000)
    assert_raises(ArgumentError) do
      Vers::Constraint.parse(huge)
    end
  end

  def test_parser_rejects_oversized_vers_uri
    huge = "vers:npm/" + ("1" * 5000)
    assert_raises(ArgumentError) do
      Vers.parse(huge)
    end
  end

  def test_parser_rejects_oversized_native_range
    huge = "^" + ("1" * 5000)
    assert_raises(ArgumentError) do
      Vers.parse_native(huge, "npm")
    end
  end

  def test_version_accepts_reasonable_long_input
    # 200 chars is unusual but legitimate (long prerelease tags exist)
    v = "1.0.0-" + ("a" * 194)
    assert_equal 200, v.length
    version = Vers::Version.new(v)
    assert_equal 1, version.major
  end

  # === Constraint count limits ===
  #
  # parse_constraints splits on [|,] without limit. npm parsing splits on
  # || without limit. Each constraint becomes an Interval object, and
  # exclusions trigger a quadratic rebuild loop.

  def test_parser_rejects_too_many_constraints
    many = (1..200).map { |i| ">=#{i}" }.join("|")
    assert_raises(ArgumentError) do
      Vers.parse("vers:npm/#{many}")
    end
  end

  def test_parser_rejects_too_many_npm_or_clauses
    many = (1..200).map { |i| "^#{i}.0.0" }.join(" || ")
    assert_raises(ArgumentError) do
      Vers.parse_native(many, "npm")
    end
  end

  def test_parser_accepts_reasonable_constraint_count
    # Real-world ranges rarely exceed a dozen constraints
    some = (1..20).map { |i| "#{i}.0.0" }.join("|")
    range = Vers.parse("vers:npm/#{some}")
    assert range.contains?("5.0.0")
  end

  # === Quadratic exclusion DoS ===
  #
  # Each != exclusion splits the range into one more interval, then
  # reconstructs the VersionRange (sort + merge). N exclusions on a range
  # that grows from 1 to N intervals does O(N^2 log N) work. With the
  # constraint count limit in place this stays bounded, but we also assert
  # the bounded case completes quickly.

  def test_many_exclusions_complete_in_reasonable_time
    # 64 exclusions sits under MAX_CONSTRAINTS and must finish fast
    excl = (1..64).map { |i| "!=#{i}.0.0" }.join("|")
    Timeout.timeout(1) do
      range = Vers.parse("vers:npm/#{excl}")
      refute range.contains?("32.0.0")
      assert range.contains?("100.0.0")
    end
  end

  def test_pathological_exclusion_count_rejected
    # Without a constraint count limit this input runs for tens of seconds
    excl = (1..2000).map { |i| "!=#{i}.0.0" }.join("|")
    assert_raises(ArgumentError) do
      Vers.parse("vers:npm/#{excl}")
    end
  end

  # === Cache key memory exhaustion ===
  #
  # Version.cached_new, Constraint.parse, and Parser caches use the raw
  # input string as a hash key. The caches evict by entry count, not by
  # byte size. With MAX_LENGTH enforced at construction, oversized input
  # raises before reaching any cache. Cache key memory is therefore
  # bounded by entry_count * MAX_LENGTH. These tests verify that the
  # length cap holds at the cache entry path and that normal-sized keys
  # still cache.

  def test_version_cached_new_rejects_oversized_input
    huge = "1.0.0-" + ("a" * 5000)
    assert_raises(ArgumentError) do
      Vers::Version.cached_new(huge)
    end
  end

  def test_version_cache_still_caches_normal_keys
    v1 = Vers::Version.cached_new("1.2.3-cachetest")
    v2 = Vers::Version.cached_new("1.2.3-cachetest")
    assert_same v1, v2, "normal version strings should hit the cache"
  end

  def test_constraint_cache_still_caches_normal_keys
    c1 = Vers::Constraint.parse(">=1.2.3-cachetest")
    c2 = Vers::Constraint.parse(">=1.2.3-cachetest")
    assert_same c1, c2, "normal constraint strings should hit the cache"
  end

  # === Maven parser bare rescue ===
  #
  # parser.rb:501 catches everything including Interrupt and NoMemoryError.
  # We can't easily test "doesn't swallow Interrupt" without signal hackery,
  # but we can assert the narrowed rescue still tolerates malformed segments.

  def test_maven_union_tolerates_malformed_segment
    # Second segment is garbage; should be skipped, first segment parsed.
    range = Vers.parse_native("[1.0,2.0],[~~~,~~~]", "maven")
    assert range.contains?("1.5")
  end

  # === Performance smoke tests ===
  #
  # Inputs near the limits should still parse in well under a second.

  def test_long_valid_version_parses_quickly
    Timeout.timeout(1) do
      100.times do |i|
        Vers::Version.new("1.0.0-rc.#{i}.build.metadata.string")
      end
    end
  end

  def test_long_valid_range_parses_quickly
    constraints = (1..50).map { |i| ">=#{i}.0.0" }.join("|")
    Timeout.timeout(1) do
      10.times { Vers.parse("vers:npm/#{constraints}") }
    end
  end
end
