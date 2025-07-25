# frozen_string_literal: true

require "test_helper"

class TestVersion < Minitest::Test
  def test_version_initialization
    version = Vers::Version.new("1.2.3")
    assert_equal 1, version.major
    assert_equal 2, version.minor
    assert_equal 3, version.patch
    assert_nil version.prerelease
  end

  def test_version_with_prerelease
    version = Vers::Version.new("1.2.3-alpha.1")
    assert_equal 1, version.major
    assert_equal 2, version.minor
    assert_equal 3, version.patch
    assert_equal "alpha.1", version.prerelease
  end

  def test_version_single_number
    version = Vers::Version.new("5")
    assert_equal 5, version.major
    assert_nil version.minor
    assert_nil version.patch
  end

  def test_version_comparison
    v1 = Vers::Version.new("1.2.3")
    v2 = Vers::Version.new("1.2.4")
    v3 = Vers::Version.new("1.2.3")

    assert_equal(-1, v1 <=> v2)
    assert_equal(1, v2 <=> v1)
    assert_equal(0, v1 <=> v3)
  end

  def test_version_comparison_with_prerelease
    v1 = Vers::Version.new("1.0.0-alpha")
    v2 = Vers::Version.new("1.0.0")
    v3 = Vers::Version.new("1.0.0-beta")

    assert_equal(-1, v1 <=> v2)  # prerelease < release
    assert_equal(1, v2 <=> v1)   # release > prerelease
    assert_equal(-1, v1 <=> v3)  # alpha < beta
  end

  def test_version_comparison_different_lengths
    v1 = Vers::Version.new("1.0")
    v2 = Vers::Version.new("1.0.0")
    v3 = Vers::Version.new("1.0.1")

    assert_equal(0, v1 <=> v2)   # 1.0 == 1.0.0
    assert_equal(-1, v1 <=> v3)  # 1.0 < 1.0.1
  end

  def test_version_to_s
    assert_equal "1.2.3", Vers::Version.new("1.2.3").to_s
    assert_equal "1.0.0", Vers::Version.new("1").to_s
    assert_equal "1.2.0", Vers::Version.new("1.2").to_s
    assert_equal "1.2.3-alpha", Vers::Version.new("1.2.3-alpha").to_s
  end

  def test_version_compare_class_method
    assert_equal(-1, Vers::Version.compare("1.2.3", "1.2.4"))
    assert_equal(1, Vers::Version.compare("2.0.0", "1.9.9"))
    assert_equal(0, Vers::Version.compare("1.0.0", "1.0.0"))
    assert_equal(0, Vers::Version.compare("1.0", "1.0.0"))
  end

  def test_version_normalize
    assert_equal "1.2.3", Vers::Version.normalize("1.2.3")
    assert_equal "1.0.0", Vers::Version.normalize("1")
    assert_equal "1.2.0", Vers::Version.normalize("1.2")
  end

  def test_version_valid
    assert Vers::Version.valid?("1.2.3")
    assert Vers::Version.valid?("1.0.0-alpha")
    assert Vers::Version.valid?("1")
    assert Vers::Version.valid?("0.0.1")
    refute Vers::Version.valid?("")
  end

  def test_version_equality
    v1 = Vers::Version.new("1.2.3")
    v2 = Vers::Version.new("1.2.3")
    v3 = Vers::Version.new("1.2.4")

    assert_equal v1, v2
    refute_equal v1, v3
  end

  def test_version_hash
    v1 = Vers::Version.new("1.2.3")
    v2 = Vers::Version.new("1.2.3")
    
    assert_equal v1.hash, v2.hash
  end

  def test_version_edge_cases
    # Test with nil comparison
    assert_equal(-1, Vers::Version.compare(nil, "1.0.0"))
    assert_equal(1, Vers::Version.compare("1.0.0", nil))
    assert_equal(0, Vers::Version.compare(nil, nil))
  end

  def test_version_prerelease_comparison_detailed
    # Test detailed prerelease comparison
    assert_equal(-1, Vers::Version.compare("1.0.0-alpha", "1.0.0-alpha.1"))
    assert_equal(-1, Vers::Version.compare("1.0.0-alpha.1", "1.0.0-alpha.beta"))
    assert_equal(-1, Vers::Version.compare("1.0.0-alpha.beta", "1.0.0-beta"))
    assert_equal(-1, Vers::Version.compare("1.0.0-beta", "1.0.0-beta.2"))
    assert_equal(-1, Vers::Version.compare("1.0.0-beta.2", "1.0.0-beta.11"))
    assert_equal(-1, Vers::Version.compare("1.0.0-beta.11", "1.0.0-rc.1"))
  end

  def test_version_with_build_metadata
    version = Vers::Version.new("1.2.3-alpha+build.123")
    assert_equal 1, version.major
    assert_equal 2, version.minor
    assert_equal 3, version.patch
    assert_equal "alpha", version.prerelease
    assert_equal "build.123", version.build
  end

  def test_version_increment_methods
    version = Vers::Version.new("1.2.3")
    
    major_incremented = version.increment(:major)
    assert_equal "2.0.0", major_incremented.to_s
    
    minor_incremented = version.increment(:minor)
    assert_equal "1.3.0", minor_incremented.to_s
    
    patch_incremented = version.increment(:patch)
    assert_equal "1.2.4", patch_incremented.to_s
  end

  def test_version_increment_shortcuts
    version = Vers::Version.new("1.2.3")
    
    assert_equal "2.0.0", version.increment_major.to_s
    assert_equal "1.3.0", version.increment_minor.to_s
    assert_equal "1.2.4", version.increment_patch.to_s
  end

  def test_version_increment_invalid_component
    version = Vers::Version.new("1.2.3")
    
    assert_raises(ArgumentError) do
      version.increment(:invalid)
    end
  end

  def test_version_satisfies_pessimistic
    version = Vers::Version.new("1.2.5")
    
    assert version.satisfies?("~> 1.2")
    assert version.satisfies?("~> 1.2.3")
    refute version.satisfies?("~> 1.3")
    refute version.satisfies?("~> 2.0")
  end

  def test_version_satisfies_pessimistic_edge_cases
    version = Vers::Version.new("1.2.0")
    assert version.satisfies?("~> 1.2")
    
    version2 = Vers::Version.new("1.3.0")
    refute version2.satisfies?("~> 1.2")
    
    version3 = Vers::Version.new("2.0.0")
    refute version3.satisfies?("~> 1.2")
  end

  def test_version_stable_and_prerelease
    stable_version = Vers::Version.new("1.2.3")
    assert stable_version.stable?
    refute stable_version.prerelease?
    
    prerelease_version = Vers::Version.new("1.2.3-alpha")
    refute prerelease_version.stable?
    assert prerelease_version.prerelease?
  end

  def test_version_to_h
    version = Vers::Version.new("1.2.3-alpha+build.123")
    hash = version.to_h
    
    assert_equal 1, hash[:major]
    assert_equal 2, hash[:minor] 
    assert_equal 3, hash[:patch]
    assert_equal "alpha", hash[:prerelease]
    assert_equal "build.123", hash[:build]
  end

  def test_version_base
    version = Vers::Version.new("1.2.5")
    base = version.base
    
    assert_equal "1.2.0", base.to_s
  end

  def test_version_increment_with_missing_components
    version = Vers::Version.new("1")
    
    assert_equal "2.0.0", version.increment_major.to_s
    assert_equal "1.1.0", version.increment_minor.to_s
    assert_equal "1.0.1", version.increment_patch.to_s
  end
end