# frozen_string_literal: true

require "yaml"

module ActionAudit
  class AuditMessages
    class << self
      def messages
        @messages ||= {}
      end

      def load_from_file(file_path)
        return unless File.exist?(file_path)

        content = YAML.load_file(file_path)
        return unless content.is_a?(Hash)

        messages.deep_merge!(content)
      end

      def load_from_engines
        # Load from all Rails engines and the main app
        if defined?(Rails) && Rails.application
          # Load from main application
          main_audit_file = Rails.root.join("config", "audit.yml")
          load_from_file(main_audit_file) if File.exist?(main_audit_file)

          # Load from all engines
          Rails.application.railties.each do |railtie|
            next unless railtie.respond_to?(:root)

            engine_audit_file = railtie.root.join("config", "audit.yml")
            load_from_file(engine_audit_file) if File.exist?(engine_audit_file)
          end
        end
      end

      def lookup(controller_path, action_name)
        # Convert controller path to nested hash lookup
        # e.g., "manage/accounts" becomes ["manage", "accounts"]
        path_parts = controller_path.split("/")

        # Navigate through nested hash structure
        current_level = messages
        path_parts.each do |part|
          current_level = current_level[part]
          return nil unless current_level.is_a?(Hash)
        end

        # Look up the action
        current_level[action_name]
      end

      def clear!
        @messages = {}
      end

      def add_message(controller_path, action_name, message)
        path_parts = controller_path.split("/")

        # Navigate/create nested structure
        current_level = messages
        path_parts.each do |part|
          current_level[part] ||= {}
          current_level = current_level[part]
        end

        # Set the message
        current_level[action_name] = message
      end
    end
  end
end
