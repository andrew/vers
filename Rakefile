# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"
require "rdoc/task"

Minitest::TestTask.create

RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = "doc"
  rdoc.title = "Vers - Version Range Parser Library"
  rdoc.main = "README.md"
  rdoc.rdoc_files.include("README.md", "lib/**/*.rb")
  rdoc.options << "--line-numbers"
  rdoc.options << "--all"
  rdoc.options << "--charset=UTF-8"
end

task default: :test

namespace :benchmark do
  desc "Run version parsing benchmarks"
  task :parse do
    require "benchmark"
    require "json"
    require_relative "lib/vers"
    
    puts "🚀 VERS Parsing Benchmarks"
    puts "=" * 50
    
    # Load sample version ranges from test-suite-data.json
    test_data_file = File.join(__dir__, "test-suite-data.json")
    
    unless File.exist?(test_data_file)
      puts "❌ test-suite-data.json not found. Using fallback examples."
      sample_ranges = [
        { input: "^1.2.3", scheme: "npm" },
        { input: "~> 1.2", scheme: "gem" },
        { input: ">=1.0,<2.0", scheme: "pypi" },
        { input: "[1.0,2.0)", scheme: "maven" }
      ]
    else
      test_data = JSON.parse(File.read(test_data_file))
      sample_ranges = test_data.select { |data| !data["is_invalid"] }.first(100)
    end
    
    puts "📊 Sample size: #{sample_ranges.length} version ranges"
    puts "📦 Schemes: #{sample_ranges.map { |r| r['scheme'] }.uniq.sort.join(', ')}"
    puts
    
    # Benchmark native parsing
    puts "🔍 Native Parsing Performance:"
    native_time = Benchmark.realtime do
      sample_ranges.each { |range| Vers.parse_native(range['input'], range['scheme']) }
    end
    
    puts "   Total time: #{(native_time * 1000).round(2)}ms"
    puts "   Average per range: #{(native_time * 1000 / sample_ranges.length).round(3)}ms"
    puts "   Ranges per second: #{(sample_ranges.length / native_time).round(0)}"
    puts
    
    # Benchmark vers URI parsing
    puts "🔤 VERS URI Parsing Performance:"
    vers_uris = []
    sample_ranges.each do |range|
      begin
        parsed = Vers.parse_native(range['input'], range['scheme'])
        vers_uri = Vers.to_vers_string(parsed, range['scheme'])
        vers_uris << vers_uri
      rescue
        # Skip invalid ranges
      end
    end
    
    vers_time = Benchmark.realtime do
      vers_uris.each { |uri| Vers.parse(uri) }
    end
    
    puts "   Total time: #{(vers_time * 1000).round(2)}ms"
    puts "   Average per URI: #{(vers_time * 1000 / vers_uris.length).round(3)}ms"
    puts "   URIs per second: #{(vers_uris.length / vers_time).round(0)}"
    puts
    
    # Benchmark version comparison
    puts "⚖️  Version Comparison Performance:"
    versions = ["1.0.0", "1.2.3", "2.0.0", "0.9.0", "1.5.0", "1.2.4"]
    comparison_pairs = versions.product(versions)
    
    comparison_time = Benchmark.realtime do
      comparison_pairs.each { |a, b| Vers.compare(a, b) }
    end
    
    puts "   #{comparison_pairs.length} comparisons: #{(comparison_time * 1000).round(2)}ms"
    puts "   Average per comparison: #{(comparison_time * 1000 / comparison_pairs.length).round(4)}ms"
    puts "   Comparisons per second: #{(comparison_pairs.length / comparison_time).round(0)}"
    puts
    
    # Benchmark containment checking
    puts "🔍 Version Containment Performance:"
    test_versions = ["1.0.0", "1.2.3", "1.5.0", "2.0.0", "0.9.0"]
    parsed_ranges = sample_ranges.first(20).map do |range|
      Vers.parse_native(range['input'], range['scheme'])
    end
    
    containment_time = Benchmark.realtime do
      parsed_ranges.each do |range|
        test_versions.each { |version| range.contains?(version) }
      end
    end
    
    total_checks = parsed_ranges.length * test_versions.length
    puts "   #{total_checks} containment checks: #{(containment_time * 1000).round(2)}ms"
    puts "   Average per check: #{(containment_time * 1000 / total_checks).round(4)}ms"
    puts "   Checks per second: #{(total_checks / containment_time).round(0)}"
    puts
    
    puts "✅ Benchmark completed!"
  end
  
  desc "Compare parsing performance across package manager schemes"
  task :schemes do
    require "benchmark"
    require "json"
    require_relative "lib/vers"
    
    puts "📊 Package Scheme Parsing Comparison"
    puts "=" * 50
    
    # Load test data and group by scheme
    test_data_file = File.join(__dir__, "test-suite-data.json")
    
    unless File.exist?(test_data_file)
      puts "❌ test-suite-data.json not found. Cannot run scheme comparison."
      exit 1
    end
    
    test_data = JSON.parse(File.read(test_data_file))
    valid_data = test_data.select { |data| !data["is_invalid"] }
    schemes = valid_data.group_by { |data| data['scheme'] }
    
    scheme_benchmarks = {}
    
    schemes.each do |scheme, scheme_data|
      next if scheme_data.length < 5  # Skip schemes with too few examples
      
      sample_data = scheme_data.first(50)  # Limit to 50 examples per scheme
      
      time = Benchmark.realtime do
        sample_data.each { |data| Vers.parse_native(data['input'], data['scheme']) }
      end
      
      avg_time_per_range = time / sample_data.length
      scheme_benchmarks[scheme] = {
        time: avg_time_per_range,
        examples_count: sample_data.length
      }
    end
    
    # Sort by performance (fastest first)
    sorted_benchmarks = scheme_benchmarks.sort_by { |_, data| data[:time] }
    
    puts "🏆 Performance Rankings (fastest to slowest):"
    puts "   Rank Scheme       Avg Time/Parse  Examples"
    puts "   " + "-" * 45
    
    sorted_benchmarks.each_with_index do |(scheme, data), index|
      rank = (index + 1).to_s.rjust(2)
      time_str = "#{(data[:time] * 1000).round(4)}ms".rjust(10)
      examples_str = data[:examples_count].to_s.rjust(8)
      
      puts "   #{rank}.  #{scheme.ljust(10)} #{time_str}    #{examples_str}"
    end
    
    fastest = sorted_benchmarks.first
    slowest = sorted_benchmarks.last
    
    puts
    puts "📈 Performance Summary:"
    puts "   Fastest: #{fastest[0]} (#{(fastest[1][:time] * 1000).round(4)}ms)"
    puts "   Slowest: #{slowest[0]} (#{(slowest[1][:time] * 1000).round(4)}ms)"
    puts "   Ratio: #{(slowest[1][:time] / fastest[1][:time]).round(1)}x difference"
    puts
    puts "✅ Scheme comparison completed!"
  end
  
  desc "Benchmark memory usage and object allocation"
  task :memory do
    require "benchmark"
    require "json"
    require "objspace"
    require_relative "lib/vers"

    puts "VERS Memory & Allocation Benchmarks"
    puts "=" * 50

    test_data_file = File.join(__dir__, "test-suite-data.json")

    unless File.exist?(test_data_file)
      puts "test-suite-data.json not found. Using fallback examples."
      sample_ranges = [
        { "input" => "^1.2.3", "scheme" => "npm" },
        { "input" => "~> 1.2", "scheme" => "gem" },
        { "input" => ">=1.0,<2.0", "scheme" => "pypi" }
      ]
    else
      test_data = JSON.parse(File.read(test_data_file))
      sample_ranges = test_data.select { |data| !data["is_invalid"] }.first(100)
    end

    puts "Sample size: #{sample_ranges.length} version ranges"
    puts

    # Measure object allocations during cold parsing (no cache)
    Vers::Version.class_variable_set(:@@version_cache, {})
    Vers::Constraint.class_variable_set(:@@constraint_cache, {})
    Vers::Parser.class_variable_set(:@@parser_cache, {})

    GC.start
    GC.disable
    before = ObjectSpace.count_objects.dup

    version_ranges = []
    sample_ranges.each do |range|
      parsed = Vers.parse_native(range['input'], range['scheme']) rescue nil
      version_ranges << parsed if parsed
    end

    after = ObjectSpace.count_objects
    GC.enable

    string_alloc = after[:T_STRING] - before[:T_STRING]
    array_alloc = after[:T_ARRAY] - before[:T_ARRAY]
    hash_alloc = after[:T_HASH] - before[:T_HASH]
    object_alloc = after[:T_OBJECT] - before[:T_OBJECT]
    match_alloc = (after[:T_MATCH] || 0) - (before[:T_MATCH] || 0)
    total_alloc = string_alloc + array_alloc + hash_alloc + object_alloc + match_alloc

    puts "Cold parse allocations (#{version_ranges.length} ranges, no cache):"
    puts "   Total objects:  #{total_alloc}"
    puts "   Strings:        #{string_alloc}"
    puts "   Arrays:         #{array_alloc}"
    puts "   Hashes:         #{hash_alloc}"
    puts "   Objects:        #{object_alloc}"
    puts "   MatchData:      #{match_alloc}"
    puts "   Per range:      #{(total_alloc.to_f / version_ranges.length).round(1)}"
    puts

    # Measure cached parse allocations (everything already cached)
    GC.start
    GC.disable
    before = ObjectSpace.count_objects.dup

    sample_ranges.each do |range|
      Vers.parse_native(range['input'], range['scheme']) rescue nil
    end

    after = ObjectSpace.count_objects
    GC.enable

    cached_strings = after[:T_STRING] - before[:T_STRING]
    cached_arrays = after[:T_ARRAY] - before[:T_ARRAY]
    cached_objects = after[:T_OBJECT] - before[:T_OBJECT]
    cached_match = (after[:T_MATCH] || 0) - (before[:T_MATCH] || 0)
    cached_alloc = cached_strings + cached_arrays + cached_objects + cached_match

    puts "Cached parse allocations (#{version_ranges.length} ranges, warm cache):"
    puts "   Total objects:  #{cached_alloc}"
    puts "   Strings:        #{cached_strings}"
    puts "   MatchData:      #{cached_match}"
    puts "   Per range:      #{(cached_alloc.to_f / version_ranges.length).round(1)}"
    puts

    # Measure memory size of retained objects
    total_memsize = version_ranges.sum { |r| ObjectSpace.memsize_of(r) }
    puts "Retained memory:"
    puts "   #{version_ranges.length} VersionRange objects: #{total_memsize} bytes"
    puts "   Average per object: #{(total_memsize.to_f / version_ranges.length).round(0)} bytes"
    puts

    # Repeated operation allocations
    puts "Repeated operation allocations (#{version_ranges.length} calls each):"

    operations = {
      "to_s" => proc { version_ranges.each(&:to_s) },
      "contains?" => proc { version_ranges.each { |r| r.contains?("1.5.0") } },
      "empty?" => proc { version_ranges.each(&:empty?) },
    }

    operations.each do |name, op|
      # Warm up
      op.call

      GC.start
      GC.disable
      before = ObjectSpace.count_objects.dup
      op.call
      after = ObjectSpace.count_objects
      GC.enable

      allocs = [:T_STRING, :T_ARRAY, :T_OBJECT, :T_MATCH, :T_HASH].sum { |k| (after[k] || 0) - (before[k] || 0) }
      puts "   #{name.ljust(15)}: #{allocs} allocations"
    end

    puts
    puts "Memory benchmark completed!"
  end
  
  desc "Run complexity stress tests"
  task :stress do
    require "benchmark"
    require_relative "lib/vers"
    
    puts "🎯 VERS Complexity Stress Tests"
    puts "=" * 50
    
    # Test different complexity levels
    complexity_tests = {
      "Simple exact" => { input: "1.2.3", scheme: "npm" },
      "Simple range" => { input: ">=1.0.0", scheme: "npm" },
      "Caret range" => { input: "^1.2.3", scheme: "npm" },
      "Complex npm" => { input: ">=1.2.3 <2.0.0 || >=3.0.0", scheme: "npm" },
      "Gem pessimistic" => { input: "~> 1.2.3", scheme: "gem" },
      "Maven bracket" => { input: "[1.0,2.0)", scheme: "maven" },
      "Python complex" => { input: ">=1.0,!=1.5.0,<2.0", scheme: "pypi" }
    }
    
    puts "🔍 Parsing Performance by Complexity:"
    puts "   Test Case                    Time/Parse   Ops/Second"
    puts "   " + "-" * 55
    
    complexity_tests.each do |test_name, test_case|
      begin
        time = Benchmark.realtime do
          1000.times { Vers.parse_native(test_case[:input], test_case[:scheme]) }
        end
        
        avg_time = time / 1000
        ops_per_sec = 1000 / time
        
        puts "   #{test_name.ljust(25)} #{(avg_time * 1000).round(4)}ms   #{ops_per_sec.round(0)}"
      rescue => e
        puts "   #{test_name.ljust(25)} ERROR: #{e.message}"
      end
    end
    
    puts
    
    # Test long input strings
    puts "📏 Large Input String Tests:"
    large_inputs = [
      "1.0.0 || 1.1.0 || 1.2.0 || 1.3.0 || 1.4.0 || 1.5.0 || 1.6.0 || 1.7.0",
      ">=1.0.0 <1.1.0 || >=1.2.0 <1.3.0 || >=1.4.0 <1.5.0 || >=1.6.0 <1.7.0",
      "^1.0.0 || ^1.1.0 || ^1.2.0 || ^1.3.0 || ^1.4.0 || ^1.5.0"
    ]
    
    large_inputs.each_with_index do |input, index|
      begin
        time = Benchmark.realtime do
          100.times { Vers.parse_native(input, "npm") }
        end
        
        avg_time = time / 100
        input_size = input.length
        
        puts "   Input #{index + 1} (#{input_size} chars): #{(avg_time * 1000).round(3)}ms per parse"
      rescue => e
        puts "   Input #{index + 1}: ERROR - #{e.message}"
      end
    end
    
    puts
    puts "✅ Stress tests completed!"
  end
  
  desc "Run all benchmarks"
  task all: [:parse, :schemes, :memory, :stress] do
    puts
    puts "🎉 All benchmarks completed!"
    puts "   Use 'rake benchmark:parse' for parsing performance"
    puts "   Use 'rake benchmark:schemes' for scheme comparison"  
    puts "   Use 'rake benchmark:memory' for memory usage analysis"
    puts "   Use 'rake benchmark:stress' for complexity stress tests"
  end
end

namespace :spec do
  desc "Show available VERS specification tasks"
  task :help do
    puts "🔧 VERS Specification Tasks"
    puts "=" * 30
    puts "rake spec:validate_spec  - Validate VERSION-RANGE-SPEC.rst is present and readable"
    puts "rake spec:examples       - Show examples of version range parsing"
    puts "rake spec:ecosystems     - Show supported package manager ecosystems"
    puts "rake spec:compliance     - Run VERS specification compliance test suite"
    puts "rake spec:test_data      - Show information about the JSON test dataset"
    puts "rake spec:help           - Show this help message"
    puts
    puts "Example workflow:"
    puts "  1. rake spec:ecosystems # Review supported ecosystems"
    puts "  2. rake test           # Run full test suite"
    puts "  3. rake spec:examples  # See parsing examples"
    puts
    puts "The specification is stored in VERSION-RANGE-SPEC.rst at the project root."
  end

  desc "Validate that the VERSION-RANGE-SPEC.rst file is present and readable"
  task :validate_spec do
    puts "🔍 Validating VERS Specification File..."
    puts "=" * 50
    
    spec_file = File.join(__dir__, "VERSION-RANGE-SPEC.rst")
    
    if File.exist?(spec_file)
      puts "✅ VERSION-RANGE-SPEC.rst found"
      puts "   File size: #{File.size(spec_file)} bytes"
      puts "   Last modified: #{File.mtime(spec_file)}"
      
      # Check if file is readable and has content
      content = File.read(spec_file)
      if content.include?("vers:")
        puts "   Contains vers: examples: ✅"
      else
        puts "   ⚠️  File may not contain valid VERS specification content"
      end
    else
      puts "❌ VERSION-RANGE-SPEC.rst not found"
      puts "   Expected location: #{spec_file}"
      exit 1
    end
  end

  desc "Show examples of version range parsing for different ecosystems"
  task :examples do
    require_relative "lib/vers"
    
    puts "🔍 VERS Version Range Parsing Examples"
    puts "=" * 50
    
    examples = [
      {
        ecosystem: "npm",
        examples: [
          { native: "^1.2.3", description: "Caret range (compatible within major)" },
          { native: "~1.2.3", description: "Tilde range (compatible within minor)" },
          { native: "1.2.3 - 2.3.4", description: "Hyphen range (inclusive)" },
          { native: ">=1.0.0 <2.0.0", description: "Space-separated constraints" }
        ]
      },
      {
        ecosystem: "gem",
        examples: [
          { native: "~> 1.2", description: "Pessimistic operator (compatible)" },
          { native: ">= 1.0, < 2.0", description: "Comma-separated constraints" }
        ]
      },
      {
        ecosystem: "pypi", 
        examples: [
          { native: ">=1.0,<2.0", description: "Comma-separated constraints" },
          { native: "!=1.5.0", description: "Exclusion constraint" }
        ]
      },
      {
        ecosystem: "maven",
        examples: [
          { native: "[1.0,2.0]", description: "Inclusive range" },
          { native: "(1.0,2.0)", description: "Exclusive range" },
          { native: "[1.0,2.0)", description: "Mixed inclusivity" }
        ]
      }
    ]
    
    examples.each do |eco|
      puts "\n📦 #{eco[:ecosystem].upcase} Examples:"
      puts "-" * 30
      
      eco[:examples].each do |example|
        begin
          range = Vers.parse_native(example[:native], eco[:ecosystem])
          vers_string = Vers.to_vers_string(range, eco[:ecosystem])
          
          puts "  Native:     #{example[:native]}"
          puts "  VERS URI:   #{vers_string}"
          puts "  Contains 1.5.0? #{range.contains?('1.5.0')}"
          puts "  Description: #{example[:description]}"
          puts
        rescue => e
          puts "  ❌ #{example[:native]} - Error: #{e.message}"
          puts
        end
      end
    end
  end

  desc "Show information about supported package manager ecosystems"
  task :ecosystems do
    require_relative "lib/vers"
    
    puts "🔍 Supported Package Manager Ecosystems"
    puts "=" * 50
    
    ecosystems = [
      {
        name: "npm",
        description: "Node.js Package Manager",
        syntax: "Caret (^), Tilde (~), Hyphen ranges",
        examples: ["^1.2.3", "~1.2.3", "1.2.3 - 2.3.4"]
      },
      {
        name: "gem",
        description: "RubyGems",
        syntax: "Pessimistic operator (~>), Standard operators",
        examples: ["~> 1.2", ">= 1.0, < 2.0"]
      },
      {
        name: "pypi",
        description: "Python Package Index",
        syntax: "Comma-separated constraints",
        examples: [">=1.0,<2.0", "!=1.5.0"]
      },
      {
        name: "maven",
        description: "Apache Maven (Java)",
        syntax: "Bracket notation with inclusivity",
        examples: ["[1.0,2.0]", "(1.0,2.0)", "[1.0,2.0)"]
      },
      {
        name: "debian",
        description: "Debian Package Manager",
        syntax: "Standard comparison operators",
        examples: [">=1.0.0", "<<2.0.0"]
      },
      {
        name: "rpm",
        description: "RPM Package Manager",
        syntax: "Standard comparison operators",
        examples: [">=1.0.0", "<=2.0.0"]
      }
    ]
    
    ecosystems.each do |eco|
      puts "\n📦 #{eco[:name].upcase}"
      puts "   Description: #{eco[:description]}"
      puts "   Syntax: #{eco[:syntax]}"
      puts "   Examples: #{eco[:examples].join(', ')}"
      
      # Test if parsing works
      begin
        test_example = eco[:examples].first
        range = Vers.parse_native(test_example, eco[:name])
        puts "   Status: ✅ Parsing functional"
      rescue => e
        puts "   Status: ❌ Parsing error: #{e.message}"
      end
    end
    
    puts "\n📊 Summary:"
    puts "   Total ecosystems: #{ecosystems.length}"
    puts "   VERS URI format: vers:<ecosystem>/<constraints>"
    puts "   Universal operations: union, intersection, complement, exclusion"
  end

  desc "Run VERS specification compliance test suite"
  task :compliance do
    puts "🧪 Running VERS Specification Compliance Tests"
    puts "=" * 50
    
    # Run only the compliance test
    system("ruby -Ilib:test test/test_vers_spec_compliance.rb")
  end

  desc "Show information about the JSON test dataset"
  task :test_data do
    require 'json'
    
    puts "📋 VERS Test Dataset Information"
    puts "=" * 50
    
    test_file = File.join(__dir__, "test-suite-data.json")
    
    if File.exist?(test_file)
      data = JSON.parse(File.read(test_file))
      
      puts "✅ test-suite-data.json found"
      puts "   File size: #{File.size(test_file)} bytes"
      puts "   Total test cases: #{data.length}"
      
      # Count by scheme
      schemes = data.group_by { |test| test['scheme'] }
      puts "\n📦 Test cases by ecosystem:"
      schemes.each do |scheme, tests|
        valid_tests = tests.select { |t| !t['is_invalid'] }
        invalid_tests = tests.select { |t| t['is_invalid'] }
        puts "   #{scheme}: #{valid_tests.length} valid, #{invalid_tests.length} invalid"
      end
      
      puts "\n🔍 Sample test cases:"
      data.first(3).each do |test|
        status = test['is_invalid'] ? 'INVALID' : 'VALID'
        puts "   [#{status}] #{test['scheme']}: #{test['input']} - #{test['description']}"
      end
      
      puts "\n💡 Usage:"
      puts "   This dataset can be used by other VERS implementations"
      puts "   for cross-language compatibility testing, similar to"
      puts "   the PURL project's test-suite-data.json"
      
    else
      puts "❌ test-suite-data.json not found"
      puts "   Expected location: #{test_file}"
    end
  end
end
