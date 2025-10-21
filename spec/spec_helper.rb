# frozen_string_literal: true

require "bundler/setup"
require "logger"

# Mock Rails before loading our gem
module Rails
  def self.logger
    @logger ||= MockLogger.new
  end

  def self.application
    @application ||= OpenStruct.new(railties: [])
  end

  def self.root
    @root ||= Pathname.new(Dir.pwd)
  end

  def self.env
    @env ||= OpenStruct.new(development?: false)
  end
end

# Mock logger with tagged support
class MockLogger < Logger
  def initialize
    super(STDOUT)
  end

  def tagged(*tags)
    yield if block_given?
  end
end

# Mock ActionController::Parameters
module ActionController
  class Parameters < Hash
    def initialize(hash = {})
      hash.each { |k, v| self[k] = v }
    end

    def to_unsafe_h
      self
    end

    def deep_stringify_keys
      result = {}
      each { |k, v| result[k.to_s] = v }
      result
    end

    def transform_keys(&block)
      result = {}
      each do |key, value|
        result[block.call(key)] = value
      end
      self.class.new(result)
    end

    def symbolize_keys
      result = {}
      each { |k, v| result[k.to_sym] = v }
      result
    end
  end
end

require "active_support/all"
require "ostruct"
require "pathname"
require "logger"
require "tempfile"
require "action_audit"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
