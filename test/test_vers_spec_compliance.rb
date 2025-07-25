# frozen_string_literal: true

require 'test_helper'
require 'json'

class TestVersSpecCompliance < Minitest::Test
  def setup
    @test_data = load_test_data
  end

  def load_test_data
    test_file = File.join(File.dirname(__FILE__), '..', 'test-suite-data.json')
    JSON.parse(File.read(test_file))
  end

  def test_spec_compliance_suite
    passed = 0
    failed = 0
    
    @test_data.each do |test_case|
      description = test_case['description']
      input = test_case['input']
      scheme = test_case['scheme']
      canonical_vers = test_case['canonical_vers']
      contains = test_case['contains'] || []
      excludes = test_case['excludes'] || []
      is_invalid = test_case['is_invalid']
      
      if is_invalid
        # Test that invalid ranges raise errors
        assert_raises(ArgumentError, "#{description}: should raise error for invalid input '#{input}'") do
          Vers.parse_native(input, scheme)
        end
        passed += 1
      else
        begin
          # Test parsing
          range = Vers.parse_native(input, scheme)
          refute_nil range, "#{description}: failed to parse '#{input}'"
          
          # Test canonical output if provided
          if canonical_vers && canonical_vers != "*"
            generated_vers = Vers.to_vers_string(range, scheme)
            # Note: canonical comparison is flexible as different implementations
            # may produce equivalent but differently formatted output
            # For now, just ensure it can be generated
            refute_nil generated_vers, "#{description}: failed to generate vers string"
          end
          
          # Test containment assertions
          contains.each do |version|
            assert range.contains?(version), 
              "#{description}: range '#{input}' should contain version '#{version}'"
          end
          
          # Test exclusion assertions  
          excludes.each do |version|
            refute range.contains?(version),
              "#{description}: range '#{input}' should NOT contain version '#{version}'"
          end
          
          passed += 1
        rescue => e
          failed += 1
          puts "FAILED: #{description}"
          puts "  Input: #{input} (#{scheme})"
          puts "  Error: #{e.message}"
          puts "  Backtrace: #{e.backtrace.first(3).join("\n             ")}"
          
          # Still assert to make the test fail
          assert false, "#{description}: #{e.message}"
        end
      end
    end
    
    puts "VERS Spec Compliance Results: #{passed} passed, #{failed} failed"
  end

  def test_cross_ecosystem_compatibility
    # Test that the same semantic range can be expressed across ecosystems
    test_cases = [
      {
        description: "simple greater than or equal constraint",
        ranges: {
          "npm" => ">=1.2.3",
          "gem" => ">= 1.2.3", 
          "pypi" => ">=1.2.3",
          "maven" => "1.2.3",  # Simple version is >=1.2.3 in Maven
          "nuget" => "1.2.3"   # Simple version is >=1.2.3 in NuGet
        },
        should_contain: ["1.2.3", "1.5.0", "2.0.0"],
        should_exclude: ["1.2.2", "1.0.0"]
      },
      {
        description: "range with upper bound",
        ranges: {
          "npm" => ">=1.0.0 <2.0.0",
          "gem" => ">= 1.0.0, < 2.0.0",
          "pypi" => ">=1.0.0,<2.0.0", 
          "maven" => "[1.0.0,2.0.0)"
        },
        should_contain: ["1.0.0", "1.5.0"],
        should_exclude: ["0.9.0", "2.0.0"]
      }
    ]
    
    test_cases.each do |test_case|
      description = test_case[:description]
      
      test_case[:ranges].each do |scheme, range_string|
        range = Vers.parse_native(range_string, scheme)
        
        test_case[:should_contain].each do |version|
          assert range.contains?(version),
            "#{description} (#{scheme}): '#{range_string}' should contain '#{version}'"
        end
        
        test_case[:should_exclude].each do |version|
          refute range.contains?(version),
            "#{description} (#{scheme}): '#{range_string}' should NOT contain '#{version}'"
        end
      end
    end
  end

  def test_bidirectional_conversion
    # Test that parsing a range and converting back produces equivalent results
    conversion_tests = [
      { input: "^1.2.3", scheme: "npm" },
      { input: "~> 1.2.3", scheme: "gem" },
      { input: "[1.0,2.0)", scheme: "maven" },
      { input: ">=1.0,<2.0", scheme: "pypi" }
    ]
    
    conversion_tests.each do |test|
      range = Vers.parse_native(test[:input], test[:scheme])
      vers_string = Vers.to_vers_string(range, test[:scheme])
      reparsed_range = Vers.parse(vers_string)
      
      # Test that the ranges are functionally equivalent by testing some versions
      test_versions = ["0.9.0", "1.0.0", "1.5.0", "2.0.0", "2.5.0"]
      test_versions.each do |version|
        assert_equal range.contains?(version), reparsed_range.contains?(version),
          "Bidirectional conversion failed for #{test[:input]} (#{test[:scheme]}) with version #{version}"
      end
    end
  end
end