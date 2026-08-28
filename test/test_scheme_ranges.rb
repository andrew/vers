# frozen_string_literal: true

require "test_helper"

class TestSchemeRanges < Minitest::Test
  def test_canonical_wildcard_is_an_unbounded_typed_range
    range = Vers.parse("vers:npm/*")

    assert_equal "npm", range.scheme
    assert range.unbounded?
    assert range.contains?("1.0.0")
    refute range.contains?("*")
  end

  def test_typed_wildcards_reject_invalid_versions
    %w[semver pub go hex].each do |scheme|
      refute Vers.parse("vers:#{scheme}/*").contains?("not-a-version")
    end
  end

  def test_parsed_range_uses_its_scheme_for_containment
    range = Vers.parse("vers:deb/<1.0")

    assert_equal "deb", range.scheme
    assert_equal "deb", range.intervals.fetch(0).scheme
    assert range.contains?("1.0~rc1")
    refute range.contains?("1.0")
  end

  def test_native_range_retains_a_canonical_alias
    range = Vers.parse_native(">=v1.2.3, <v2.0.0", "golang")

    assert_equal "go", range.scheme
    assert range.intervals.all? { |interval| interval.scheme == "go" }
    assert range.contains?("v1.5.0")
  end

  def test_serializer_emits_the_canonical_scheme_for_an_alias
    range = Vers.parse_native("~> 1.2", "rubygems")

    assert_equal "vers:gem/>=1.2|<2", Vers.to_vers_string(range, "rubygems")
  end

  def test_serializer_rejects_a_different_scheme
    range = Vers.parse_native("^1.2.3", "npm")

    assert_raises(ArgumentError) { Vers.to_vers_string(range, "pypi") }
  end

  def test_range_algebra_preserves_the_scheme
    range = Vers.parse("vers:rpm/>=1.0~rc1|<2.0").exclude("1.0").complement

    assert_equal "rpm", range.scheme
    assert range.intervals.all? { |interval| interval.scheme == "rpm" }
  end

  def test_range_algebra_rejects_different_schemes
    npm = Vers.parse("vers:npm/>=1.0.0")
    pypi = Vers.parse("vers:pypi/>=1.0")

    assert_raises(ArgumentError) { npm.union(pypi) }
    assert_raises(ArgumentError) { npm.intersect(pypi) }
  end

  def test_cargo_intersection_uses_range_equality_for_build_metadata
    foo = Vers.parse("vers:cargo/1.0.0+foo")
    bar = Vers.parse("vers:cargo/1.0.0+bar")

    [foo.intersect(bar), bar.intersect(foo)].each do |intersection|
      assert intersection.contains?("1.0.0+foo")
      assert intersection.contains?("1.0.0+bar")
    end
  end

  def test_pypi_intersection_preserves_a_local_exact_version
    public_version = Vers.parse("vers:pypi/1.0")
    local_version = Vers.parse("vers:pypi/1.0+abc")

    [public_version.intersect(local_version), local_version.intersect(public_version)].each do |intersection|
      assert intersection.contains?("1.0+abc")
      refute intersection.contains?("1.0+def")
    end
  end

  def test_union_preserves_an_exclusion_outside_the_other_operand
    excluded = Vers.parse("vers:npm/>=1.0.0").exclude("1.5.0")
    later = Vers.parse("vers:npm/>=2.0.0")
    union = excluded.union(later)

    refute union.contains?("1.5.0")
    refute later.union(excluded).contains?("1.5.0")
    refute Vers.parse(Vers.to_vers_string(union, "npm")).contains?("1.5.0")
  end

  def test_union_drops_an_exclusion_covered_by_the_other_operand
    excluded = Vers.parse("vers:npm/>=1.0.0").exclude("1.5.0")
    covering = Vers.parse("vers:npm/>=1.4.0")

    assert excluded.union(covering).contains?("1.5.0")
    assert covering.union(excluded).contains?("1.5.0")
  end

  def test_untyped_range_inherits_a_typed_scheme
    generic = Vers::VersionRange.greater_than("1.0.dev1", inclusive: true)
    pypi = Vers.parse("vers:pypi/*")

    intersection = generic.intersect(pypi)

    assert_equal "pypi", intersection.scheme
    assert intersection.contains?("1.0a1")
  end

  def test_flat_constraints_form_separate_bounded_intervals
    range = Vers.parse("vers:conan/>1|<2.0|>=3.2|<4-")

    assert range.contains?("1.5")
    refute range.contains?("2.1")
    assert range.contains?("3.3")
  end
end
