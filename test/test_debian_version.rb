# frozen_string_literal: true

require "test_helper"

class TestDebianVersion < Minitest::Test
  def assert_ordered(*versions)
    versions.each_cons(2) do |lower, higher|
      assert_equal(-1, Vers.compare_with_scheme(lower, higher, "deb"), "#{lower} should sort before #{higher}")
      assert_equal 1, Vers.compare_with_scheme(higher, lower, "deb"), "#{higher} should sort after #{lower}"
    end
  end

  def test_a_version_sorts_before_the_same_version_with_more_characters
    assert_ordered "1.0", "1.0a", "1.0b"
    assert_ordered "1.0", "1.0+b1"
    assert_ordered "2.0.", "2.0.a"
    assert_ordered "1.0-1", "1.0-1a", "1.0-1+b1"
    assert_ordered "1.0", "1.0.1", "1.0.1a"
  end

  def test_a_tilde_sorts_before_the_end_of_a_part
    assert_ordered "1.0~rc1", "1.0", "1.0a"
    assert_ordered "1.0~~", "1.0~", "1.0"
    assert_ordered "1.0-1~bpo1", "1.0-1"
  end

  def test_letters_sort_before_other_characters
    assert_ordered "1.0a", "1.0+"
    assert_ordered "1.0z", "1.0."
  end
end
