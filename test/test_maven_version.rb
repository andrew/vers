# frozen_string_literal: true

require "test_helper"

class TestMavenVersion < Minitest::Test
  def test_basic_numeric_ordering
    assert_equal(-1, Vers::MavenVersion.compare("1", "2"))
    assert_equal(1, Vers::MavenVersion.compare("2", "1"))
    assert_equal(0, Vers::MavenVersion.compare("1", "1"))
  end

  def test_multi_part_ordering
    assert_equal(-1, Vers::MavenVersion.compare("1.5", "2"))
    assert_equal(-1, Vers::MavenVersion.compare("1.0", "1.1"))
    assert_equal(-1, Vers::MavenVersion.compare("1.0.0", "1.1"))
  end

  def test_qualifier_ordering
    # alpha < beta < milestone < rc < snapshot < "" (release) < sp
    assert_equal(-1, Vers::MavenVersion.compare("1-alpha", "1-beta"))
    assert_equal(-1, Vers::MavenVersion.compare("1-beta", "1-milestone"))
    assert_equal(-1, Vers::MavenVersion.compare("1-milestone", "1-rc"))
    assert_equal(-1, Vers::MavenVersion.compare("1-rc", "1-snapshot"))
    assert_equal(-1, Vers::MavenVersion.compare("1-snapshot", "1"))
    assert_equal(-1, Vers::MavenVersion.compare("1", "1-sp"))
  end

  def test_qualifier_aliases
    # cr == rc
    assert_equal(0, Vers::MavenVersion.compare("1-cr1", "1-rc1"))
    # ga == release == final == "" (release)
    assert_equal(0, Vers::MavenVersion.compare("1-ga", "1"))
    assert_equal(0, Vers::MavenVersion.compare("1-final", "1"))
    assert_equal(0, Vers::MavenVersion.compare("1-release", "1"))
  end

  def test_trailing_zero_normalization
    assert_equal(0, Vers::MavenVersion.compare("1.0", "1"))
    assert_equal(0, Vers::MavenVersion.compare("1.0.0", "1"))
  end

  def test_digit_letter_transitions
    # digit-to-letter transition creates a sublist
    assert_equal(-1, Vers::MavenVersion.compare("1alpha1", "1.0"))
    assert_equal(-1, Vers::MavenVersion.compare("1alpha1", "1"))
  end

  def test_single_letter_qualifier_expansion
    # a -> alpha only when followed by digit
    assert_equal(0, Vers::MavenVersion.compare("1-a1", "1-alpha-1"))
    assert_equal(0, Vers::MavenVersion.compare("1-b1", "1-beta-1"))
    assert_equal(0, Vers::MavenVersion.compare("1-m1", "1-milestone-1"))
  end

  def test_sublist_vs_direct_rules
    # sublist (afterDash) < direct numeric
    assert_equal(-1, Vers::MavenVersion.compare("1-1", "1.1"))
    # sublist > direct string
    assert_equal(1, Vers::MavenVersion.compare("1-1", "1-sp"))
  end

  def test_unknown_qualifiers_alphabetical
    assert_equal(-1, Vers::MavenVersion.compare("1-aaa", "1-bbb"))
    assert_equal(1, Vers::MavenVersion.compare("1-zzz", "1-aaa"))
  end

  def test_case_insensitive
    assert_equal(0, Vers::MavenVersion.compare("1-ALPHA", "1-alpha"))
    assert_equal(0, Vers::MavenVersion.compare("1-Beta", "1-beta"))
  end

  def test_equal_strings_shortcircuit
    assert_equal(0, Vers::MavenVersion.compare("1.2.3-alpha", "1.2.3-alpha"))
  end

  def test_prerelease_less_than_release
    assert_equal(-1, Vers::MavenVersion.compare("1.0-alpha", "1.0"))
    assert_equal(-1, Vers::MavenVersion.compare("1.0-rc1", "1.0"))
  end

  def test_sp_greater_than_release
    assert_equal(1, Vers::MavenVersion.compare("1.0-sp1", "1.0"))
  end
end
