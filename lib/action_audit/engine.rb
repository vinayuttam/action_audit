# frozen_string_literal: true

module ActionAudit
  class Engine < ::Rails::Engine
    isolate_namespace ActionAudit

    initializer "action_audit.load_audit_messages", after: :load_config_initializers do
      ActionAudit::AuditMessages.load_from_engines
    end

    # Reload audit messages in development when files change
    config.to_prepare do
      if Rails.env.development?
        ActionAudit::AuditMessages.clear!
        ActionAudit::AuditMessages.load_from_engines
      end
    end
  end
end
