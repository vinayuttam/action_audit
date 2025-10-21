# frozen_string_literal: true

require "rails/generators"

module ActionAudit
  class InstallGenerator < Rails::Generators::Base
    desc "Install ActionAudit configuration"

    def self.source_root
      @source_root ||= File.expand_path("templates", __dir__)
    end

    def copy_audit_config
      template "audit.yml", "config/audit.yml"
    end

    def create_initializer
      template "action_audit.rb", "config/initializers/action_audit.rb"
    end

    def show_readme
      readme "README"
    end
  end
end
