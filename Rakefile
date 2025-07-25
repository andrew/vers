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
