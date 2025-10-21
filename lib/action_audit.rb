# frozen_string_literal: true

require "active_support"
require "active_support/concern"
require "rails"

require_relative "action_audit/version"
require_relative "action_audit/audit_messages"
require_relative "action_audit/engine" if defined?(Rails)

module ActionAudit
  class Error < StandardError; end

  # Configuration attributes
  mattr_accessor :log_formatter, default: nil
  mattr_accessor :log_tag, default: nil

  extend ActiveSupport::Concern

  included do
    after_action :audit_request
  end

  private

  def audit_request
    controller_path = self.class.name.underscore.gsub("_controller", "")
    action_name = action_name()

    # Look up the audit message
    message = ActionAudit::AuditMessages.lookup(controller_path, action_name)
    return unless message

    # Interpolate the message with params
    interpolated_message = interpolate_message(message, params)

    # Format the log entry
    formatted_message = if ActionAudit.log_formatter
      ActionAudit.log_formatter.call(controller_path, action_name, interpolated_message)
    else
      "#{controller_path}/#{action_name} - #{interpolated_message}"
    end

    # Log with optional tag
    if ActionAudit.log_tag
      Rails.logger.tagged(ActionAudit.log_tag) do
        Rails.logger.info(formatted_message)
      end
    else
      Rails.logger.info(formatted_message)
    end
  end

  def interpolate_message(message, interpolation_params)
    return "" if message.nil?
    return message.to_s unless message.respond_to?(:%)

    # Convert params to hash with symbol keys for interpolation
    unsafe_hash = interpolation_params.to_unsafe_h
    string_params = unsafe_hash.respond_to?(:deep_stringify_keys) ? unsafe_hash.deep_stringify_keys : unsafe_hash

    # Convert to symbol keys for string interpolation
    symbol_params = {}
    string_params.each { |k, v| symbol_params[k.to_sym] = v }

    # Perform string interpolation
    message % symbol_params
  rescue KeyError => e
    # If interpolation fails, log the original message with error info
    "#{message} (interpolation error: #{e.message})"
  rescue TypeError
    # If message is not a string or doesn't support %, return as-is
    message.to_s
  end
end
