# frozen_string_literal: true

require 'test_helper'
require 'json'

class TestVersSpecSuite < Minitest::Test
  SPEC_DIR = File.join(File.dirname(__FILE__), 'vers-spec', 'tests')
  SUPPORTED_SCHEMES = %w[gem maven npm nuget pypi].freeze

  def test_version_comparison
    each_test_file("_version_cmp_test.json") do |test_case|
      scheme = test_case.dig('input', 'input_scheme')
      next unless SUPPORTED_SCHEMES.include?(scheme)

      versions = test_case.dig('input', 'versions')
      expected = test_case['expected_output']

      if test_case['test_type'] == 'equality'
        result = Vers.compare_with_scheme(versions[0], versions[1], scheme)
        if expected == true
          assert_equal 0, result, "#{test_case['description']}: #{versions[0]} should equal #{versions[1]}"
        else
          refute_equal 0, result, "#{test_case['description']}: #{versions[0]} should not equal #{versions[1]}"
        end
      else
        sorted = versions.sort { |a, b| Vers.compare_with_scheme(a, b, scheme) }
        # NuGet prerelease tags are case-insensitive; normalize for comparison
        if scheme == 'nuget'
          sorted = sorted.map { |v| normalize_nuget_version(v) }
        end
        assert_equal expected, sorted, "#{test_case['description']}: sorting #{versions.inspect}"
      end
    end
  end

  def test_range_from_native
    each_test_file("_range_from_native_test.json") do |test_case|
      scheme = test_case.dig('input', 'scheme')
      next unless SUPPORTED_SCHEMES.include?(scheme)

      native_range = test_case.dig('input', 'native_range')
      expected_vers = test_case['expected_output']

      range = Vers.parse_native(native_range, scheme)
      generated = Vers.to_vers_string(range, scheme)

      assert_equal expected_vers, generated,
        "#{test_case['description']}: native '#{native_range}'"
    end
  end

  def test_range_containment
    each_test_file("_range_containment_test.json") do |test_case|
      vers_string = test_case.dig('input', 'vers')
      version = test_case.dig('input', 'version')
      expected = test_case['expected_output']

      scheme = vers_string.match(/\Avers:([^\/]+)\//)[1] rescue nil
      next unless scheme && SUPPORTED_SCHEMES.include?(scheme)

      range = Vers.parse(vers_string)
      result = range.contains?(version)
      assert_equal expected, result,
        "#{test_case['description']}: #{vers_string} contains? #{version}"
    end
  end

  def each_test_file(suffix)
    Dir.glob(File.join(SPEC_DIR, "*#{suffix}")).each do |file|
      data = JSON.parse(File.read(file))
      data['tests'].each { |test_case| yield test_case }
    end
  end

  def normalize_nuget_version(version)
    if version.include?('-')
      base, rest = version.split('-', 2)
      if rest.include?('+')
        pre, build = rest.split('+', 2)
        "#{base}-#{pre.downcase}+#{build}"
      else
        "#{base}-#{rest.downcase}"
      end
    else
      version
    end
  end
end
